const fs = require("fs");
const path = require("path");

const projectDir = __dirname;
const catalog = JSON.parse(fs.readFileSync(path.join(projectDir, "catalog-data.json"), "utf8"));
const endpoint = "https://elemental-dungeons-roblox.fandom.com/api.php";
const aliases = {
  "Normal Wooden Bow": "Wooden Bow",
  "Watergun LE": "Watergun",
  "BootlegPhantom": "Phantom",
  "BootlegSolar": "Solar",
  "Conqueror's BladeTL": "Conqueror's Blade",
  "Conqueror's BladeTL LE": "Conqueror's Blade",
  "TerrabladeLE": "Terrablade",
  "AscDaggers": "Ascended Daggers",
};

const normalize = value => value.toLowerCase().replace(/[^a-z0-9]/g, "");
const splitCamel = value => value.replace(/([a-z])([A-Z])/g, "$1 $2");
const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

async function api(parameters) {
  const url = new URL(endpoint);
  for (const [key, value] of Object.entries({ action: "query", format: "json", origin: "*", ...parameters })) {
    url.searchParams.set(key, value);
  }
  const response = await fetch(url, { headers: { "User-Agent": "ElementalAbilityCatalog/1.0" } });
  if (!response.ok) throw new Error(`Wiki API ${response.status}`);
  return response.json();
}

function scoreImage(image, owner, category) {
  const name = image.name || "";
  const normalizedName = normalize(name.replace(/\.[^.]+$/, ""));
  const normalizedOwner = normalize(owner);
  const words = splitCamel(owner).toLowerCase().split(/[^a-z0-9]+/).filter(word => word.length > 2);
  let score = 0;
  if (normalizedName === normalizedOwner) score += 180;
  if (normalizedName === normalizedOwner + "icon") score += 230;
  if (normalizedName.includes(normalizedOwner)) score += 90;
  if (normalizedName.includes("icon")) score += 65;
  if (normalizedName.includes("inventory")) score += 35;
  score += words.filter(word => normalizedName.includes(word)).length * 18;
  if (/\.(png|webp|jpe?g)$/i.test(name)) score += 25;
  if (category === "Elements" && normalizedName.includes("element")) score += 15;
  if (/gif|button|key|showcase|ability|moveset|banner|logo|screenshot|awakening/i.test(name)) score -= 110;
  return score;
}

async function findIcon(owner, category) {
  const lookup = aliases[owner] || splitCamel(owner);
  const prefixes = [...new Set([
    lookup,
    lookup.replace(/[ '\-]/g, "_"),
    lookup.split(/\s+/)[0],
  ].filter(Boolean))];
  const candidates = [];
  for (const prefix of prefixes) {
    try {
      const data = await api({ list: "allimages", aiprefix: prefix, ailimit: "50", aiprop: "url|mime|size" });
      candidates.push(...(data.query?.allimages || []));
    } catch (error) {
      process.stderr.write(`${owner}: ${error.message}\n`);
    }
    await sleep(35);
  }
  const unique = [...new Map(candidates.map(image => [image.name, image])).values()];
  unique.sort((a, b) => scoreImage(b, lookup, category) - scoreImage(a, lookup, category));
  const winner = unique[0];
  return winner && scoreImage(winner, lookup, category) >= 75 ? winner.url : null;
}

async function main() {
  const owners = [...new Map(catalog.abilities.map(ability => [
    `${ability.category}|${ability.owner}`,
    { category: ability.category, owner: ability.owner },
  ])).values()];
  const result = { elements: {}, weapons: {}, source: "Elemental Dungeons Roblox Wiki" };
  let completed = 0;
  for (const item of owners) {
    const url = await findIcon(item.owner, item.category);
    if (url) {
      const destination = item.category === "Elements" ? result.elements : result.weapons;
      destination[item.owner] = url;
    }
    completed += 1;
    process.stdout.write(`\rIcons ${completed}/${owners.length}`);
  }
  process.stdout.write("\n");
  fs.writeFileSync(path.join(projectDir, "wiki-icons.json"), JSON.stringify(result, null, 2));
  console.log(JSON.stringify({ elements: Object.keys(result.elements).length, weapons: Object.keys(result.weapons).length }));
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
