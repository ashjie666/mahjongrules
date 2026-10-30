// Cloudflare Pages 直传部署脚本
// 用法：先在环境变量里设置 CF_TOKEN / CF_ACCOUNT，然后 node deploy-pages.mjs
// 流程：建项目(已存在则跳过) -> 计算 sha256 -> check-missing -> upload/upsert -> 建部署 -> 绑定域名

import { createHash } from "node:crypto";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative, sep } from "node:path";

const API = "https://api.cloudflare.com/client/v4";
const TOKEN = process.env.CF_TOKEN;
const ACCOUNT = process.env.CF_ACCOUNT;
const PROJECT = process.env.CF_PROJECT || "mahjongrules";
const ROOT = "L:\\site\\majiang\\web";
const BRANCH = "main";
const DOMAIN = "mahjongrules.fun";

if (!TOKEN || !ACCOUNT) {
  console.error("缺少环境变量 CF_TOKEN 或 CF_ACCOUNT");
  process.exit(1);
}

const HEADERS = {
  Authorization: `Bearer ${TOKEN}`,
  "Content-Type": "application/json",
};

async function api(path, method = "GET", body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: HEADERS,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { status: res.status, ok: res.ok && json.success !== false, json };
}

const CT = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".xml": "application/xml; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".ico": "image/x-icon",
  ".webp": "image/webp",
};

function contentType(name) {
  const i = name.lastIndexOf(".");
  return CT[name.slice(i).toLowerCase()] || "application/octet-stream";
}

function walk(dir) {
  const out = [];
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    if (statSync(full).isDirectory()) out.push(...walk(full));
    else out.push(full);
  }
  return out;
}

const files = walk(ROOT).map((full) => {
  const buf = readFileSync(full);
  const rel = "/" + relative(ROOT, full).split(sep).join("/");
  return {
    rel,
    hash: createHash("sha256").update(buf).digest("hex"),
    b64: buf.toString("base64"),
    ct: contentType(full),
  };
});

console.log(`[1/5] 本地文件 ${files.length} 个，合计 ${(files.reduce((n, f) => n + f.b64.length, 0) / 1024).toFixed(0)} KB(base64)`);

// 1. 建项目
const created = await api(`/accounts/${ACCOUNT}/pages/projects`, "POST", {
  name: PROJECT,
  production_branch: BRANCH,
});
if (created.ok) {
  console.log(`[2/5] 项目已创建：${PROJECT}`);
} else {
  const msg = JSON.stringify(created.json.errors || created.json);
  if (/already exists|duplicate|8000001|8000002/i.test(msg)) {
    console.log(`[2/5] 项目已存在，继续：${PROJECT}`);
  } else {
    console.error(`[2/5] 建项目失败 ${created.status} ${msg}`);
    process.exit(1);
  }
}

// 2. 取短时 JWT，资产接口必须用它鉴权
const tokRes = await api(`/accounts/${ACCOUNT}/pages/projects/${PROJECT}/upload-token`);
if (!tokRes.ok || !tokRes.json.result?.jwt) {
  console.error(`[3/5] 取 upload-token 失败 ${tokRes.status} ${JSON.stringify(tokRes.json.errors || tokRes.json)}`);
  process.exit(1);
}
const jwt = tokRes.json.result.jwt;

async function apiJwt(path, method = "GET", body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch {
    json = { raw: text };
  }
  return { status: res.status, ok: res.ok && json.success !== false, json };
}

const hashes = [...new Set(files.map((f) => f.hash))];
const missing = await apiJwt(`/pages/assets/check-missing`, "POST", {
  hashes,
});
if (!missing.ok) {
  console.error(`[3/5] check-missing 失败 ${missing.status} ${JSON.stringify(missing.json.errors || missing.json)}`);
  process.exit(1);
}
const missingSet = new Set(missing.json.result || []);
console.log(`[3/5] 已存在 ${hashes.length - missingSet.size} 个，需上传 ${missingSet.size} 个`);

// 3. upload + upsert
const pending = files.filter((f) => missingSet.has(f.hash));
const body = pending.map((f) => ({
  key: f.hash,
  value: f.b64,
  base64: true,
  metadata: { contentType: f.ct },
}));

async function push(kind, payload) {
  const BATCH = 6;
  for (let i = 0; i < payload.length; i += BATCH) {
    const chunk = payload.slice(i, i + BATCH);
    const r = await apiJwt(`/pages/assets/${kind}`, "POST", chunk);
    if (!r.ok) {
      console.error(`${kind} 失败 ${r.status} ${JSON.stringify(r.json.errors || r.json)}`);
      process.exit(1);
    }
  }
}

if (body.length) {
  await push("upload", body);
}
console.log(`[4/5] 资产上传完成`);

// 4. 建部署（multipart/form-data，manifest 为 JSON 字符串，键不带前导斜杠）
const manifest = {};
for (const f of files) manifest[f.rel.replace(/^\//, "")] = f.hash;

const fd = new FormData();
fd.append("branch", BRANCH);
fd.append("manifest", JSON.stringify(manifest));

const depRes = await fetch(`${API}/accounts/${ACCOUNT}/pages/projects/${PROJECT}/deployments`, {
  method: "POST",
  headers: { Authorization: `Bearer ${TOKEN}` },
  body: fd,
});
const depText = await depRes.text();
let depJson;
try {
  depJson = JSON.parse(depText);
} catch {
  depJson = { raw: depText };
}
if (!depRes.ok || depJson.success === false) {
  console.error(`[5/5] 建部署失败 ${depRes.status} ${JSON.stringify(depJson.errors || depJson).slice(0, 600)}`);
  process.exit(1);
}
const d = depJson.result || {};
console.log(`[5/5] 部署成功：${d.url || d.aliases?.[0] || "(无 URL)"} id=${d.id}`);

// 5. 绑定自定义域名
const dom = await api(`/accounts/${ACCOUNT}/pages/projects/${PROJECT}/domains`, "POST", {
  name: DOMAIN,
});
if (dom.ok) console.log(`域名已绑定：${DOMAIN}`);
else {
  const msg = JSON.stringify(dom.json.errors || dom.json);
  console.log(`域名绑定未成功（可手动处理）：${msg}`);
}
