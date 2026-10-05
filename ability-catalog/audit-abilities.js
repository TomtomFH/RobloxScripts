const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const projectDir = __dirname;
const solWorkspace = "C:/Users/fabia/Downloads/Sol/workspace";
const manifestPath = path.join(solWorkspace, "AbilityHoldScan.json");
const decompiledDir = path.join(solWorkspace, "AbilityHoldDecompiled");
const astTool = "C:/Users/fabia/Documents/Codex/2026-09-20/we-wi/work/luau-0.739/luau-ast.exe";
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));

const excludedPathParts = [".OtherForms.", ".AlternateChildren.", ".Templates.", ".Player.", ".Spirits."];
const baseEntries = manifest.filter(entry => !excludedPathParts.some(part => entry.path.includes(part)));

function relativeId(entry) {
  return entry.path.replace("ReplicatedStorage.ReplicatedStorage.Abilities.", "");
}

function fieldNumber(source, names) {
  for (const name of names) {
    const match = source.match(new RegExp(`${name}\\s*=\\s*(-?[0-9]+(?:\\.[0-9]+)?)`));
    if (match) return Number(match[1]);
  }
  return null;
}

function fieldString(source, name) {
  return source.match(new RegExp(`${name}\\s*=\\s*"([^"]+)"`))?.[1] || null;
}

function children(node) {
  if (!node || typeof node !== "object") return [];
  const result = [];
  for (const [key, value] of Object.entries(node)) {
    if (["location", "type", "functionDepth", "debugname", "luauType"].includes(key)) continue;
    if (Array.isArray(value)) {
      for (const item of value) if (item && typeof item === "object" && item.type) result.push(item);
    } else if (value && typeof value === "object" && value.type) {
      result.push(value);
    }
  }
  return result;
}

function functionName(statement, recordKey = null) {
  if (recordKey) return recordKey;
  if (statement.debugname) return statement.debugname;
  if (statement.name?.name) return statement.name.name;
  if (statement.name?.index) return statement.name.index;
  if (statement.func?.debugname) return statement.func.debugname;
  return null;
}

function collectFunctions(ast) {
  const functions = new Map();
  function visit(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "AstStatLocalFunction" || node.type === "AstStatFunction") {
      const name = functionName(node);
      if (name && node.func) functions.set(name, node.func);
    }
    if (node.type === "AstStatLocal" && node.vars?.length === 1 && node.values?.[0]?.type === "AstExprFunction") {
      functions.set(node.vars[0].name, node.values[0]);
    }
    if (node.type === "AstStatAssign" && node.vars?.length === 1 && node.values?.[0]?.type === "AstExprFunction") {
      const name = node.vars[0].index || node.vars[0].name;
      if (name) functions.set(name, node.values[0]);
    }
    if (node.type === "AstExprTable") {
      for (const item of node.items || []) {
        const key = item.key?.value;
        if (item.kind === "record" && typeof key === "string" && item.value?.type === "AstExprFunction") {
          functions.set(key, item.value);
        }
      }
    }
    for (const child of children(node)) visit(child);
  }
  visit(ast.root);
  return functions;
}

function primitiveValue(node) {
  if (node?.type === "AstExprConstantNumber" || node?.type === "AstExprConstantString" || node?.type === "AstExprConstantBool") {
    return node.value;
  }
  if (node?.type === "AstExprUnary" && node.op === "Minus" && node.expr?.type === "AstExprConstantNumber") {
    return -Number(node.expr.value);
  }
  return undefined;
}

function tableData(table) {
  const result = {};
  for (const item of table?.items || []) {
    if (item.kind !== "record" || typeof item.key?.value !== "string") continue;
    const value = primitiveValue(item.value);
    if (value !== undefined) result[item.key.value] = value;
  }
  return result;
}

function collectModuleData(ast) {
  let result = {};
  function visit(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "AstExprTable") {
      const item = (node.items || []).find(entry => entry.kind === "record" && entry.key?.value === "Data" && entry.value?.type === "AstExprTable");
      if (item) result = { ...result, ...tableData(item.value) };
    }
    if (node.type === "AstStatAssign") {
      for (let index = 0; index < (node.vars || []).length; index += 1) {
        if (node.vars[index]?.index === "Data" && node.values?.[index]?.type === "AstExprTable") {
          result = { ...result, ...tableData(node.values[index]) };
        }
      }
    }
    for (const child of children(node)) visit(child);
  }
  visit(ast.root);
  return result;
}

function callMemberName(call) {
  return call?.type === "AstExprCall" && call.func?.type === "AstExprIndexName" ? call.func.index : null;
}

function callLocalName(call) {
  if (call?.type !== "AstExprCall") return null;
  if (call.func?.type === "AstExprLocal") return call.func.local?.name || null;
  if (call.func?.type === "AstExprGlobal") return call.func.global || null;
  return null;
}

function isSignalConnect(call) {
  if (callMemberName(call) !== "Connect") return false;
  let current = call.func?.expr;
  while (current) {
    if (current.type === "AstExprIndexName" && current.index === "Signal") return true;
    current = current.expr;
  }
  return false;
}

function isFrameConnect(call) {
  if (callMemberName(call) !== "Connect") return false;
  let current = call.func?.expr;
  while (current) {
    if (current.type === "AstExprIndexName" && ["Heartbeat", "RenderStepped", "Stepped"].includes(current.index)) return true;
    current = current.expr;
  }
  return false;
}

function constantNumber(node) {
  return node?.type === "AstExprConstantNumber" ? Number(node.value) : null;
}

function analyzeRoot(rootName, functions) {
  const root = functions.get(rootName);
  if (!root) return { mouse: [], damage: [], selfRelease: false, waits: [] };
  const result = { mouse: [], damage: [], selfRelease: false, waits: [] };
  const activeHelpers = new Set();

  function visit(node, context) {
    if (!node || typeof node !== "object") return;
    const loopNode = ["AstStatWhile", "AstStatRepeat", "AstStatFor", "AstStatForIn"].includes(node.type);
    const nextContext = { ...context, repeated: context.repeated || loopNode };

    if (node.type === "AstExprCall") {
      const member = callMemberName(node);
      const localName = callLocalName(node);
      if (["GetMouseData", "GetHit", "GetInstanceOnHit"].includes(member)) {
        result.mouse.push({
          method: member,
          phase: nextContext.phase,
          repeated: nextContext.repeated,
          rangeLiteral: constantNumber(node.args?.[3]),
        });
      }
      if (/^(?:Damage|DamageWithin|PassiveDamage)/.test(member || "")) {
        result.damage.push({ method: member, phase: nextContext.phase });
      }
      if (member === "Fire") {
        let current = node.func?.expr;
        let signal = false;
        while (current) {
          if (current.type === "AstExprIndexName" && current.index === "Signal") signal = true;
          current = current.expr;
        }
        if (signal && nextContext.phase !== "postRelease") result.selfRelease = true;
      }
      if (localName === "wait" || (node.func?.type === "AstExprIndexName" && node.func.index === "wait")) {
        const value = constantNumber(node.args?.[0]);
        if (value != null) result.waits.push({ value, phase: nextContext.phase });
      }

      const signalConnect = isSignalConnect(node);
      const frameConnect = isFrameConnect(node);
      for (const arg of node.args || []) {
        if (arg?.type === "AstExprFunction") {
          visit(arg.body, {
            phase: signalConnect ? "postRelease" : nextContext.phase,
            repeated: nextContext.repeated || frameConnect,
          });
        } else {
          visit(arg, nextContext);
        }
      }
      if (node.func) visit(node.func, nextContext);

      if (localName && functions.has(localName) && !activeHelpers.has(localName)) {
        activeHelpers.add(localName);
        visit(functions.get(localName).body, nextContext);
        activeHelpers.delete(localName);
      }
      const receiverName = node.func?.type === "AstExprIndexName" && node.func.expr?.type === "AstExprLocal"
        ? node.func.expr.local?.name
        : null;
      if (member && receiverName === "module" && functions.has(member) && !activeHelpers.has(member)) {
        activeHelpers.add(member);
        visit(functions.get(member).body, nextContext);
        activeHelpers.delete(member);
      }
      return;
    }

    if (node.type === "AstExprFunction") {
      visit(node.body, nextContext);
      return;
    }
    for (const child of children(node)) visit(child, nextContext);
  }

  activeHelpers.add(rootName);
  visit(root.body, { phase: rootName === "ServerFunction" ? "instant" : "holding", repeated: false });
  return result;
}

function mergeAnalyses(...items) {
  return {
    mouse: items.flatMap(item => item.mouse),
    damage: items.flatMap(item => item.damage),
    selfRelease: items.some(item => item.selfRelease),
    waits: items.flatMap(item => item.waits),
  };
}

const rows = [];
for (let index = 0; index < baseEntries.length; index += 1) {
  const entry = baseEntries[index];
  const file = path.join(decompiledDir, `${path.basename(entry.file, ".luac")}.lua`);
  const source = fs.readFileSync(file, "utf8");
  const astResult = spawnSync(astTool, [file], { encoding: "utf8", maxBuffer: 128 * 1024 * 1024 });
  if (astResult.status !== 0) throw new Error(`AST failed for ${entry.file}: ${astResult.stderr}`);
  const ast = JSON.parse(astResult.stdout);
  const functions = collectFunctions(ast);
  const data = collectModuleData(ast);
  const start = analyzeRoot("StartHoldingServer", functions);
  const instant = analyzeRoot("ServerFunction", functions);
  const server = mergeAnalyses(start, instant);
  const client = analyzeRoot("StartHoldingClient", functions);
  const duration = data.Duration ?? data.MoveDuration ?? null;
  const cooldown = data.Cooldown ?? null;
  const chargeTime = data.MaximumHoldTime ?? data.MaxHoldTime ?? data.ChargeTime ?? data.MinimumHoldTime ?? null;
  const serverMouse = server.mouse.filter(event => event.method === "GetMouseData");
  const serverHit = server.mouse.filter(event => event.method !== "GetMouseData");
  const clientMouse = client.mouse.filter(event => event.method === "GetMouseData");
  const repeatedHolding = serverMouse.some(event => event.phase === "holding" && event.repeated);
  const repeatedAfterCast = serverMouse.some(event => event.phase !== "holding" && event.repeated);
  const clientRepeatedHolding = clientMouse.some(event => event.phase === "holding" && event.repeated);
  const clientRepeatedAfterCast = clientMouse.some(event => event.phase !== "holding" && event.repeated);
  const postCastWait = Math.max(0,
    ...server.waits.filter(wait => wait.phase !== "holding").map(wait => wait.value),
    ...client.waits.filter(wait => wait.phase !== "holding").map(wait => wait.value));
  const trackAfterRelease = repeatedAfterCast || clientRepeatedAfterCast
    ? Math.max(duration || 0, postCastWait ? postCastWait + 1 : 0, 2.5) + 0.35
    : 0;
  const holdForDuration = repeatedHolding || clientRepeatedHolding || start.selfRelease || client.selfRelease;
  const hold = chargeTime != null
    ? chargeTime + 0.05
    : holdForDuration && duration != null
      ? duration + 0.35
      : holdForDuration
        ? Math.min(cooldown || 6, 8) + 0.35
      : 0.12;
  rows.push({
    id: relativeId(entry),
    title: data.Title || fieldString(source, "Title") || entry.name,
    data,
    sourceFile: entry.file,
    roots: [...functions.keys()].filter(name => ["StartHoldingServer", "ServerFunction", "StartHoldingClient"].includes(name)),
    serverMouseReads: serverMouse.length,
    serverHitReads: serverHit.length,
    serverDamageCalls: server.damage.length,
    clientMouseReads: clientMouse.length,
    rangeLiterals: [...new Set(server.mouse.map(event => event.rangeLiteral).filter(value => Number.isFinite(value)))],
    clientRangeLiterals: [...new Set(client.mouse.map(event => event.rangeLiteral).filter(value => Number.isFinite(value)))],
    repeatedHolding,
    repeatedAfterCast,
    clientRepeatedHolding,
    clientRepeatedAfterCast,
    serverSelfRelease: start.selfRelease,
    clientSelfRelease: client.selfRelease,
    duration,
    cooldown,
    chargeTime,
    hold,
    trackAfterRelease,
    waits: server.waits,
  });
  process.stdout.write(`\rAST audit ${index + 1}/${baseEntries.length}`);
}
process.stdout.write("\n");
fs.writeFileSync(path.join(projectDir, "ability-audit.json"), JSON.stringify(rows, null, 2));
console.log(JSON.stringify({
  abilities: rows.length,
  serverMouse: rows.filter(row => row.serverMouseReads > 0).length,
  repeatedHolding: rows.filter(row => row.repeatedHolding).length,
  repeatedAfterCast: rows.filter(row => row.repeatedAfterCast).length,
  selfReleasing: rows.filter(row => row.serverSelfRelease || row.clientSelfRelease).length,
}));
