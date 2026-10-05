const fs = require("fs");
const path = require("path");

const solWorkspace = "C:/Users/fabia/Downloads/Sol/workspace";
const manifestPath = path.join(solWorkspace, "AbilityHoldScan.json");
const decompiledDir = path.join(solWorkspace, "AbilityHoldDecompiled");
const metadataPath = path.join(solWorkspace, "AbilityOwnerMetadata.json");
const projectDir = __dirname;
const outputDir = path.join(projectDir, "dist");
const wikiMetadataPath = path.join(projectDir, "wiki-icons.json");
const auditPath = path.join(projectDir, "ability-audit.json");

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const metadata = fs.existsSync(metadataPath)
  ? JSON.parse(fs.readFileSync(metadataPath, "utf8"))
  : { elements: {}, weapons: {}, keybinds: {} };
const wikiMetadata = fs.existsSync(wikiMetadataPath)
  ? JSON.parse(fs.readFileSync(wikiMetadataPath, "utf8"))
  : { elements: {}, weapons: {} };
if (!fs.existsSync(auditPath)) {
  throw new Error("Run node audit-abilities.js before generating the catalog.");
}
const auditById = new Map(JSON.parse(fs.readFileSync(auditPath, "utf8")).map(item => [item.id, item]));

const keyLabels = { 0: "M1", 1: "F", 2: "R", 3: "C", 4: "V", 5: "G" };
const utilityAbilityIds = new Set([
  "Bow.Wooden Bow.ChargedHeal",
  "Elements.Nightmare.LucidStep",
  "Sword.Cupid's Fury.BondofDungeoners",
  "Sword.Cupid's Wrath.BondofDungeoners",
  "Sword.SeriousStaff.Jumpscare",
  "Sword.WilbertStaff.Jumpscare",
]);
const manuallySkippedAbilityIds = new Set([
  "Elements.Solar.SolarDrive",
]);

function fieldString(source, name) {
  const match = source.match(new RegExp(`${name}\\s*=\\s*"([^"]+)"`));
  return match ? match[1] : null;
}

function fieldNumber(source, names) {
  for (const name of names) {
    const match = source.match(new RegExp(`${name}\\s*=\\s*(-?[0-9]+(?:\\.[0-9]+)?)`));
    if (match) return Number(match[1]);
  }
  return null;
}

function functionBlock(source, functionName) {
  const start = source.search(new RegExp(`function module\\.${functionName}\\(`));
  if (start < 0) return "";
  const rest = source.slice(start);
  const next = rest.slice(1).search(/\nfunction module\./);
  return next < 0 ? rest : rest.slice(0, next + 1);
}

function minLoopMouseDistance(block) {
  const loopPattern = /(?:Heartbeat|RenderStepped|Stepped):Connect/g;
  const mousePattern = /GetMouseData/g;
  const loops = [...block.matchAll(loopPattern)].map((match) => match.index);
  const mice = [...block.matchAll(mousePattern)].map((match) => match.index);
  let minimum = Number.POSITIVE_INFINITY;
  for (const loop of loops) {
    const mouse = mice.find((position) => position > loop);
    if (mouse !== undefined) minimum = Math.min(minimum, mouse - loop);
  }
  return minimum;
}

function normalizeIcon(value) {
  if (typeof value !== "string" || !value) return null;
  if (/^https?:\/\//i.test(value)) return value;
  const id = value.match(/rbxassetid:\/\/(\d+)/i)?.[1]
    || value.match(/[?&]id=(\d+)/i)?.[1]
    || (/^\d+$/.test(value) ? value : null);
  return id
    ? `https://www.roblox.com/asset-thumbnail/image?assetId=${id}&width=150&height=150&format=png`
    : null;
}

const baseEntries = manifest.filter((entry) =>
  !entry.path.includes(".OtherForms.")
  && !entry.path.includes(".AlternateChildren.")
  && !entry.path.includes(".Templates.")
  && !entry.path.includes(".Player.")
  && !entry.path.includes(".Spirits."));

const abilities = baseEntries.map((entry) => {
  const decompiledName = `${path.basename(entry.file, ".luac")}.lua`;
  const source = fs.readFileSync(path.join(decompiledDir, decompiledName), "utf8");
  const relativePath = entry.path.replace("ReplicatedStorage.ReplicatedStorage.Abilities.", "");
  const pathParts = relativePath.split(".");
  const category = pathParts[0];
  const owner = pathParts[1];
  const audit = auditById.get(relativePath);
  if (!audit) throw new Error(`Missing syntax-tree audit for ${relativePath}`);
  const mouseReads = audit.serverMouseReads;
  const hitReads = audit.serverHitReads;
  const damaging = !utilityAbilityIds.has(relativePath) && (
    audit.serverDamageCalls > 0 || relativePath === "Elements.Gravity.AwakenedMoves.Singularity"
  );
  const clientTargeted = mouseReads === 0 && audit.clientMouseReads > 0 && damaging;
  const manuallySkipped = manuallySkippedAbilityIds.has(relativePath);
  const supported = (mouseReads > 0 || clientTargeted) && damaging && !manuallySkipped;
  const duration = audit.duration;
  const chargeTime = audit.chargeTime;
  const keybind = typeof audit.data.Keybind === "number" ? audit.data.Keybind : 0;
  const continuous = supported && (audit.repeatedHolding || audit.clientRepeatedHolding);
  const postCastTracking = supported && (audit.repeatedAfterCast || audit.clientRepeatedAfterCast);
  const mouseRanges = [...audit.rangeLiterals, ...audit.clientRangeLiterals];
  const range = clientTargeted
    ? audit.data.AimRange ?? audit.data.FlightRange ?? audit.data.DivekickMaxDistance
      ?? audit.data.Distance ?? (Math.max(0, ...mouseRanges) || null) ?? audit.data.Range
    : audit.data.Range ?? audit.data.ProjectileMaxDistance ?? (Math.max(0, ...mouseRanges) || null);
  const iconSource = category === "Elements"
    ? metadata.elements?.[owner] || wikiMetadata.elements?.[owner]
    : metadata.weapons?.[owner] || wikiMetadata.weapons?.[owner];

  return {
    id: relativePath,
    category,
    owner,
    title: audit.title,
    keybind,
    key: keyLabels[keybind] || `Slot ${keybind}`,
    cooldown: audit.cooldown,
    range,
    duration,
    chargeTime,
    forceRelease: /ServerForceReleases\s*=\s*true/.test(source),
    mouseReads,
    hitReads,
    damaging,
    supported,
    clientTargeted,
    mode: supported ? (continuous ? "Held tracking" : postCastTracking ? "Post-cast tracking" : "Release aim") : "Not used",
    trackAfterRelease: supported ? audit.trackAfterRelease : 0,
    reason: manuallySkipped
      ? "Explicitly excluded from automatic casting"
      : supported
      ? (clientTargeted && continuous ? "Client-steered attack tracks the target while active"
        : clientTargeted ? "Client aim steers the damaging move toward the target"
        : continuous ? "Tracks the target while the ability is held"
        : postCastTracking ? "Keeps tracking after the ability is activated"
        : "Aims at the target when the attack commits")
      : (mouseReads > 0 ? "Targeted utility or support ability"
        : audit.clientMouseReads > 0 && audit.serverDamageCalls > 0
          ? "Client-only steering; no server attack target"
          : "Does not read a server-side mouse target"),
    icon: normalizeIcon(iconSource),
  };
}).sort((a, b) =>
  a.category.localeCompare(b.category)
  || a.owner.localeCompare(b.owner)
  || a.keybind - b.keybind
  || a.title.localeCompare(b.title));

const supportedProfiles = abilities.filter((ability) => ability.supported).map((ability) => ({
  id: ability.id,
  category: ability.category,
  owner: ability.owner,
  title: ability.title,
  keybind: ability.keybind,
  range: ability.range || 500,
  cooldown: ability.cooldown || 1,
  hold: auditById.get(ability.id).hold,
  continuous: ability.mode === "Held tracking",
  trackAfterRelease: ability.trackAfterRelease,
}));

fs.mkdirSync(outputDir, { recursive: true });
fs.writeFileSync(path.join(projectDir, "catalog-data.json"), JSON.stringify({ abilities, supportedProfiles }, null, 2));
fs.writeFileSync(path.join(projectDir, "generated-profiles.json"), JSON.stringify(supportedProfiles));
const luaRows = supportedProfiles.map((profile) => `    {${[
  profile.category,
  profile.owner,
  profile.title,
  profile.keybind,
  profile.range,
  profile.cooldown,
  Number(profile.hold.toFixed(2)),
  profile.continuous,
  profile.id,
  Number(profile.trackAfterRelease.toFixed(2)),
].map((value) => typeof value === "string" ? JSON.stringify(value) : String(value)).join(", ")}},`);
fs.writeFileSync(path.join(projectDir, "generated-profiles.lua"), `local targetedAbilityProfileRows = {\n${luaRows.join("\n")}\n}\n`);

const payload = JSON.stringify(abilities).replace(/<\//g, "<\\/");
const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Elemental Dungeons — Ability Targeting Matrix</title>
  <meta name="description" content="A syntax-tree-audited overview of Elemental Dungeons abilities and automatic targeting support.">
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='16' fill='%23070a12'/%3E%3Cpath d='M12 38 31 9l21 29-20 17Z' fill='%235dd6ff'/%3E%3Ccircle cx='33' cy='35' r='9' fill='%23070a12'/%3E%3Ccircle cx='33' cy='35' r='4' fill='%23ffca5c'/%3E%3C/svg%3E">
  <style>
    :root{color-scheme:dark;--bg:#070a12;--panel:#101520;--panel2:#151c29;--line:#263247;--text:#f4f7fb;--muted:#9eabc0;--cyan:#5dd6ff;--gold:#ffca5c;--green:#57df9b;--red:#ff6d83;--violet:#a78bfa}
    *{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:radial-gradient(circle at 15% -5%,#172940 0,transparent 34rem),radial-gradient(circle at 95% 0,#251b45 0,transparent 30rem),var(--bg);color:var(--text);font:16px/1.5 Inter,ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;min-height:100vh}
    body:before{content:"";position:fixed;inset:0;pointer-events:none;opacity:.18;background-image:linear-gradient(rgba(255,255,255,.035) 1px,transparent 1px),linear-gradient(90deg,rgba(255,255,255,.035) 1px,transparent 1px);background-size:38px 38px;mask-image:linear-gradient(to bottom,#000,transparent 75%)}
    .shell{width:min(1480px,calc(100% - 32px));margin:auto;padding:28px 0 64px;position:relative}.top{display:flex;gap:24px;align-items:flex-end;justify-content:space-between;margin-bottom:22px}.eyebrow{font-size:.78rem;letter-spacing:.15em;text-transform:uppercase;color:var(--cyan);font-weight:800;margin-bottom:5px}h1{margin:0;font-size:clamp(1.9rem,4vw,3.6rem);line-height:1.02;letter-spacing:-.045em}.lede{color:var(--muted);max-width:760px;margin:10px 0 0}.stats{display:grid;grid-template-columns:repeat(3,minmax(90px,1fr));gap:8px;min-width:330px}.stat{background:rgba(16,21,32,.76);border:1px solid var(--line);border-radius:14px;padding:11px 13px}.stat strong{font-size:1.35rem;display:block}.stat span{font-size:.76rem;color:var(--muted);text-transform:uppercase;letter-spacing:.08em}
    .toolbar{position:sticky;top:10px;z-index:20;display:grid;grid-template-columns:minmax(220px,1fr) auto auto;gap:10px;padding:10px;background:rgba(10,14,23,.88);backdrop-filter:blur(18px);border:1px solid var(--line);border-radius:18px;box-shadow:0 16px 50px #0008;margin-bottom:20px}.search{position:relative}.search input{width:100%;height:44px;border:1px solid var(--line);background:#0c111b;color:var(--text);border-radius:12px;padding:0 14px 0 42px;font:inherit;outline:none}.search input:focus{border-color:var(--cyan);box-shadow:0 0 0 3px #5dd6ff20}.search:before{content:"⌕";position:absolute;left:15px;top:7px;color:var(--muted);font-size:1.35rem}.segmented{display:flex;gap:4px;background:#0c111b;border:1px solid var(--line);border-radius:12px;padding:4px}.segmented button{border:0;background:transparent;color:var(--muted);font:700 .85rem/1 inherit;padding:0 12px;border-radius:8px;cursor:pointer;min-height:34px}.segmented button[aria-pressed="true"]{color:#071018;background:var(--cyan)}
    .legend{display:flex;align-items:center;gap:16px;color:var(--muted);font-size:.86rem;margin:0 3px 16px}.legend span{display:flex;align-items:center;gap:7px}.dot{width:9px;height:9px;border-radius:50%;background:var(--green);box-shadow:0 0 12px currentColor}.dot.off{background:#536074;box-shadow:none}.dot.live{background:var(--violet)}
    .owners{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:14px}.owner{border:1px solid var(--line);border-radius:18px;background:linear-gradient(155deg,rgba(22,29,43,.96),rgba(12,16,25,.96));overflow:hidden;box-shadow:0 18px 50px #0003}.owner-head{display:grid;grid-template-columns:58px 1fr auto;gap:12px;align-items:center;padding:14px;border-bottom:1px solid var(--line)}.owner-icon{width:58px;height:58px;border-radius:15px;display:grid;place-items:center;overflow:hidden;background:linear-gradient(135deg,#273650,#152033);border:1px solid #ffffff15;color:var(--cyan);font-size:1.2rem;font-weight:900;letter-spacing:.04em}.owner[data-category="Sword"] .owner-icon{color:var(--gold);background:linear-gradient(135deg,#493b24,#201b16)}.owner[data-category="Bow"] .owner-icon{color:#fb93c0;background:linear-gradient(135deg,#45263a,#21151d)}.owner-icon img{width:100%;height:100%;object-fit:cover}.owner h2{font-size:1.04rem;margin:0}.owner-meta{color:var(--muted);font-size:.78rem;margin-top:2px}.coverage{font-size:.78rem;color:var(--muted);text-align:right}.coverage b{display:block;color:var(--green);font-size:1rem}.ability-list{display:grid}.ability{padding:12px 14px;border-bottom:1px solid #202a3a;display:grid;grid-template-columns:minmax(0,1fr) auto;gap:8px 12px}.ability:last-child{border-bottom:0}.ability.unsupported{opacity:.58}.ability-title{font-weight:760;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ability-path{font-size:.75rem;color:var(--muted);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.badges{display:flex;justify-content:flex-end;align-items:flex-start;gap:5px;flex-wrap:wrap}.badge{font-size:.69rem;font-weight:800;letter-spacing:.035em;text-transform:uppercase;padding:4px 7px;border-radius:7px;background:#253044;color:#c6d1e3}.badge.ok{background:#12382d;color:#72efb3}.badge.live{background:#302858;color:#c3afff}.badge.key{background:#283749;color:var(--cyan);min-width:27px;text-align:center}.specs{grid-column:1/-1;display:flex;gap:11px;flex-wrap:wrap;color:#aeb9ca;font-size:.76rem}.specs span:before{content:"·";margin-right:11px;color:#4e6079}.specs span:first-child:before{display:none}.empty{grid-column:1/-1;text-align:center;padding:70px 20px;color:var(--muted);border:1px dashed var(--line);border-radius:18px}.foot{color:var(--muted);font-size:.78rem;margin-top:24px;text-align:center}
    @media(max-width:900px){.top{align-items:flex-start;flex-direction:column}.stats{width:100%;min-width:0}.toolbar{grid-template-columns:1fr}.segmented{overflow:auto}.segmented button{flex:1;white-space:nowrap}.owners{grid-template-columns:1fr}}@media(max-width:520px){.shell{width:min(100% - 20px,1480px);padding-top:18px}.stats{grid-template-columns:1fr 1fr}.stat:last-child{grid-column:1/-1}.owner-head{grid-template-columns:50px 1fr auto}.owner-icon{width:50px;height:50px}.ability{grid-template-columns:1fr}.badges{justify-content:flex-start}}
  </style>
</head>
<body>
  <main class="shell">
    <header class="top">
      <div><div class="eyebrow">Elemental Dungeons · targeting catalog</div><h1>Ability Targeting Matrix</h1><p class="lede">Every unique element and weapon ability, checked through server targeting, shared helpers, client steering, and delayed tracking used by the automatic combat script.</p></div>
      <div class="stats" aria-label="Catalog summary"><div class="stat"><strong id="supportedCount">0</strong><span>Auto-used</span></div><div class="stat"><strong id="totalCount">0</strong><span>Abilities</span></div><div class="stat"><strong id="ownerCount">0</strong><span>Sources</span></div></div>
    </header>
    <section class="toolbar" aria-label="Catalog filters">
      <label class="search"><span hidden>Search abilities</span><input id="search" type="search" placeholder="Search ability, element or weapon…" autocomplete="off"></label>
      <div class="segmented" id="statusFilter"><button data-value="all" aria-pressed="true">All</button><button data-value="supported" aria-pressed="false">Auto-used</button><button data-value="unsupported" aria-pressed="false">Not used</button></div>
      <div class="segmented" id="typeFilter"><button data-value="all" aria-pressed="true">All types</button><button data-value="Elements" aria-pressed="false">Elements</button><button data-value="weapons" aria-pressed="false">Weapons</button></div>
    </section>
    <div class="legend"><span><i class="dot"></i>Auto-used</span><span><i class="dot live"></i>Sustained tracking</span><span><i class="dot off"></i>Not used</span></div>
    <section class="owners" id="owners" aria-live="polite"></section>
    <p class="foot">Support means a damaging move reads a server mouse target or uses client-side mouse steering that can be aimed safely. All 264 base modules were syntax-tree audited; cosmetic forms reuse their base entry. Catalog icons are sourced from the game when available, with Elemental Dungeons Roblox Wiki artwork as a fallback.</p>
  </main>
  <script>
    const abilities = ${payload};
    const state = { query: "", status: "all", type: "all" };
    const ownersNode = document.querySelector("#owners");
    const esc = (value) => String(value).replace(/[&<>"']/g, character => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[character]));
    const initial = name => name.split(/\\s+/).map(part => part[0]).join("").slice(0,2).toUpperCase();
    const formatNumber = value => value == null ? null : Number.isInteger(value) ? String(value) : value.toFixed(1);
    function setFilter(group, value){state[group]=value;const node=document.querySelector("#"+group+"Filter");node.querySelectorAll("button").forEach(button=>button.setAttribute("aria-pressed",String(button.dataset.value===value)));render()}
    document.querySelector("#search").addEventListener("input", event => {state.query=event.target.value.trim().toLowerCase();render()});
    document.querySelectorAll(".segmented").forEach(group => group.addEventListener("click", event => {const button=event.target.closest("button");if(!button)return;setFilter(group.id.replace("Filter",""),button.dataset.value)}));
    function matches(ability){const haystack=[ability.title,ability.owner,ability.category,ability.id].join(" ").toLowerCase();const queryMatch=!state.query||haystack.includes(state.query);const statusMatch=state.status==="all"||(state.status==="supported"?ability.supported:!ability.supported);const typeMatch=state.type==="all"||(state.type==="weapons"?ability.category!=="Elements":ability.category===state.type);return queryMatch&&statusMatch&&typeMatch}
    function renderAbility(item){
      const modeBadge=item.mode==="Held tracking"?'<span class="badge live">Held aim</span>':item.mode==="Post-cast tracking"?'<span class="badge live">Post-cast aim</span>':'';
      const statusBadges=item.supported?'<span class="badge ok">Auto</span>'+modeBadge:'<span class="badge">Skipped</span>';
      const specs=['<span>'+esc(item.reason)+'</span>'];
      if(item.range!=null)specs.push('<span>'+formatNumber(item.range)+' studs</span>');
      if(item.cooldown!=null)specs.push('<span>'+formatNumber(item.cooldown)+'s cooldown</span>');
      if(item.duration!=null)specs.push('<span>'+formatNumber(item.duration)+'s duration</span>');
      return '<div class="ability '+(item.supported?'':'unsupported')+'"><div><div class="ability-title">'+esc(item.title)+'</div><div class="ability-path" title="'+esc(item.id)+'">'+esc(item.id)+'</div></div><div class="badges"><span class="badge key">'+esc(item.key)+'</span>'+statusBadges+'</div><div class="specs">'+specs.join('')+'</div></div>';
    }
    function renderOwner(key,items){
      const parts=key.split("|");const category=parts[0];const owner=parts.slice(1).join("|");const supported=items.filter(item=>item.supported).length;const icon=items.find(item=>item.icon)?.icon;
      const fallback=esc(initial(owner));
      const iconMarkup=icon?'<img src="'+esc(icon)+'" alt="" loading="lazy">':fallback;
      return '<article class="owner" data-category="'+esc(category)+'"><header class="owner-head"><div class="owner-icon">'+iconMarkup+'</div><div><h2>'+esc(owner)+'</h2><div class="owner-meta">'+esc(category==="Elements"?"Element":category)+'</div></div><div class="coverage"><b>'+supported+'/'+items.length+'</b>used</div></header><div class="ability-list">'+items.map(renderAbility).join('')+'</div></article>';
    }
    function render(){
      const filtered=abilities.filter(matches);const groups=new Map();for(const ability of filtered){const key=ability.category+"|"+ability.owner;if(!groups.has(key))groups.set(key,[]);groups.get(key).push(ability)}
      if(!groups.size){ownersNode.innerHTML='<div class="empty">No abilities match these filters.</div>';return}
      ownersNode.innerHTML=[...groups.entries()].map(entry=>renderOwner(entry[0],entry[1])).join("")
    }
    document.querySelector("#supportedCount").textContent=abilities.filter(item=>item.supported).length;
    document.querySelector("#totalCount").textContent=abilities.length;
    document.querySelector("#ownerCount").textContent=new Set(abilities.map(item=>item.category+"|"+item.owner)).size;
    render();
  </script>
</body>
</html>`;

fs.writeFileSync(path.join(outputDir, "index.html"), html);
console.log(JSON.stringify({
  abilities: abilities.length,
  supported: supportedProfiles.length,
  owners: new Set(abilities.map((ability) => `${ability.category}|${ability.owner}`)).size,
  icons: new Set(abilities.filter((ability) => ability.icon).map((ability) => `${ability.category}|${ability.owner}`)).size,
}));
