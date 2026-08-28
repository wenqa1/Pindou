import { createServer as createHTTPServer } from "node:http";
import { readFile } from "node:fs/promises";
import { existsSync, mkdirSync } from "node:fs";
import { dirname, extname, join, normalize, resolve } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { randomUUID } from "node:crypto";
import { pathToFileURL } from "node:url";

const maximumBodyBytes = 64 * 1024;
const movementKinds = new Map([
    ["inbound", 1],
    ["outbound", -1],
    ["stocktakeIncrease", 1],
    ["stocktakeDecrease", -1],
    ["outboundReversal", 1],
    ["inboundReversal", -1]
]);

export function createBeanWarehouseServer({ dataPath, publicPath }) {
    mkdirSync(dirname(dataPath), { recursive: true });
    const database = new DatabaseSync(dataPath);
    initializeDatabase(database);

    const server = createHTTPServer(async (request, response) => {
        try {
            const url = new URL(request.url ?? "/", "http://localhost");

            if (request.method === "GET" && url.pathname === "/api/health") {
                return sendJSON(response, 200, { status: "ok" });
            }
            if (request.method === "GET" && url.pathname === "/api/inventory") {
                return sendJSON(response, 200, inventoryResponse(database));
            }
            if (request.method === "GET" && url.pathname === "/api/movements") {
                return sendJSON(response, 200, movementsResponse(database, url.searchParams));
            }
            if (request.method === "GET" && url.pathname === "/api/settings") {
                return sendJSON(response, 200, settingsResponse(database));
            }
            if (request.method === "PUT" && url.pathname === "/api/settings") {
                const body = await readJSON(request);
                return sendJSON(response, 200, updateSettings(database, body));
            }
            if (request.method === "POST" && url.pathname === "/api/movements") {
                const body = await readJSON(request);
                return sendJSON(response, 201, createMovement(database, body));
            }
            if (request.method === "GET") {
                return await serveStaticFile(response, publicPath, url.pathname);
            }

            return sendJSON(response, 404, { error: "未找到接口。" });
        } catch (error) {
            const status = error instanceof RequestError ? error.status : 500;
            const message = error instanceof RequestError ? error.message : "服务器暂时无法完成操作。";
            return sendJSON(response, status, { error: message });
        }
    });
    server.on("close", () => database.close());
    return server;
}

function initializeDatabase(database) {
    database.exec(`
        PRAGMA journal_mode = WAL;
        PRAGMA foreign_keys = ON;
        CREATE TABLE IF NOT EXISTS inventory_movements (
            id TEXT PRIMARY KEY NOT NULL,
            brand_id TEXT NOT NULL,
            series_id TEXT NOT NULL,
            color_code TEXT NOT NULL,
            kind TEXT NOT NULL,
            quantity INTEGER NOT NULL CHECK(quantity > 0),
            occurred_at TEXT NOT NULL,
            idempotency_key TEXT NOT NULL UNIQUE
        );
        CREATE INDEX IF NOT EXISTS inventory_movements_sku_time
            ON inventory_movements(brand_id, series_id, color_code, occurred_at DESC);
        CREATE TABLE IF NOT EXISTS application_settings (
            name TEXT PRIMARY KEY NOT NULL,
            value TEXT NOT NULL
        );
    `);
    database.prepare(
        "INSERT OR IGNORE INTO application_settings(name, value) VALUES (?, ?)"
    ).run("lowStockThreshold", "7000");
}

function inventoryResponse(database) {
    const threshold = lowStockThreshold(database);
    const rows = database.prepare(`
        SELECT
            brand_id AS brandID,
            series_id AS seriesID,
            color_code AS colorCode,
            COALESCE(SUM(CASE
                WHEN kind IN ('inbound', 'stocktakeIncrease', 'outboundReversal') THEN quantity
                ELSE -quantity
            END), 0) AS onHand
        FROM inventory_movements
        GROUP BY brand_id, series_id, color_code
        ORDER BY brand_id COLLATE NOCASE, series_id COLLATE NOCASE, color_code COLLATE NOCASE
    `).all();
    const items = rows.map((row) => {
        const onHand = Number(row.onHand);
        return {
            brandID: row.brandID,
            seriesID: row.seriesID,
            colorCode: row.colorCode,
            onHand,
            available: Math.max(onHand, 0),
            lowStock: Math.max(onHand, 0) < threshold
        };
    });

    return {
        lowStockThreshold: threshold,
        totals: {
            onHand: items.reduce((total, item) => total + Math.max(item.onHand, 0), 0),
            available: items.reduce((total, item) => total + item.available, 0),
            lowStockCount: items.filter((item) => item.lowStock).length
        },
        items
    };
}

function movementsResponse(database, searchParams) {
    const brandID = normalizedOptionalText(searchParams.get("brandID"));
    const seriesID = normalizedOptionalText(searchParams.get("seriesID"));
    const colorCode = normalizedOptionalText(searchParams.get("colorCode"));
    const filters = [];
    const values = [];

    for (const [column, value] of [["brand_id", brandID], ["series_id", seriesID], ["color_code", colorCode]]) {
        if (value) {
            filters.push(`${column} = ?`);
            values.push(value);
        }
    }

    const where = filters.length > 0 ? `WHERE ${filters.join(" AND ")}` : "";
    const movements = database.prepare(`
        SELECT
            id,
            brand_id AS brandID,
            series_id AS seriesID,
            color_code AS colorCode,
            kind,
            quantity,
            occurred_at AS occurredAt
        FROM inventory_movements
        ${where}
        ORDER BY occurred_at DESC, id DESC
        LIMIT 200
    `).all(...values).map((row) => ({ ...row, quantity: Number(row.quantity) }));

    return { movements };
}

function settingsResponse(database) {
    return { lowStockThreshold: lowStockThreshold(database) };
}

function updateSettings(database, body) {
    const threshold = positiveInteger(body.lowStockThreshold, "低库存阈值");
    database.prepare("UPDATE application_settings SET value = ? WHERE name = ?")
        .run(String(threshold), "lowStockThreshold");
    return { lowStockThreshold: threshold };
}

function createMovement(database, body) {
    const brandID = requiredText(body.brandID, "品牌");
    const seriesID = requiredText(body.seriesID, "系列");
    const colorCode = requiredText(body.colorCode, "色号").toUpperCase();
    const kind = requiredText(body.kind, "流水类型");
    const quantity = positiveInteger(body.quantity, "数量");
    const idempotencyKey = requiredText(body.idempotencyKey ?? randomUUID(), "提交标识");

    if (!movementKinds.has(kind)) {
        throw new RequestError(400, "不支持的流水类型。");
    }

    database.exec("BEGIN IMMEDIATE");
    try {
        const existing = database.prepare(
            "SELECT id FROM inventory_movements WHERE idempotency_key = ?"
        ).get(idempotencyKey);
        if (existing) {
            database.exec("COMMIT");
            return { id: existing.id, duplicate: true };
        }

        const available = currentAvailable(database, brandID, seriesID, colorCode);
        if (kind === "outbound" && quantity > available) {
            throw new RequestError(409, `可用库存仅 ${available} 颗，无法出库 ${quantity} 颗。`);
        }

        const movement = {
            id: randomUUID(),
            brandID,
            seriesID,
            colorCode,
            kind,
            quantity,
            occurredAt: new Date().toISOString(),
            idempotencyKey
        };
        database.prepare(`
            INSERT INTO inventory_movements(
                id, brand_id, series_id, color_code, kind, quantity, occurred_at, idempotency_key
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `).run(
            movement.id,
            movement.brandID,
            movement.seriesID,
            movement.colorCode,
            movement.kind,
            movement.quantity,
            movement.occurredAt,
            movement.idempotencyKey
        );
        database.exec("COMMIT");
        return { ...movement, duplicate: false };
    } catch (error) {
        database.exec("ROLLBACK");
        throw error;
    }
}

function currentAvailable(database, brandID, seriesID, colorCode) {
    const row = database.prepare(`
        SELECT COALESCE(SUM(CASE
            WHEN kind IN ('inbound', 'stocktakeIncrease', 'outboundReversal') THEN quantity
            ELSE -quantity
        END), 0) AS onHand
        FROM inventory_movements
        WHERE brand_id = ? AND series_id = ? AND color_code = ?
    `).get(brandID, seriesID, colorCode);
    return Math.max(Number(row.onHand), 0);
}

async function readJSON(request) {
    const chunks = [];
    let size = 0;
    for await (const chunk of request) {
        size += chunk.length;
        if (size > maximumBodyBytes) {
            throw new RequestError(413, "请求内容过大。");
        }
        chunks.push(chunk);
    }

    try {
        return JSON.parse(Buffer.concat(chunks).toString("utf8"));
    } catch {
        throw new RequestError(400, "请求不是有效 JSON。" );
    }
}

async function serveStaticFile(response, publicPath, pathname) {
    const requestedPath = pathname === "/" ? "/index.html" : pathname;
    const filePath = resolve(publicPath, `.${normalize(requestedPath)}`);
    if (!filePath.startsWith(`${resolve(publicPath)}${process.platform === "win32" ? "\\" : "/"}`)) {
        return sendJSON(response, 403, { error: "无权访问该资源。" });
    }

    try {
        const content = await readFile(filePath);
        const contentType = {
            ".css": "text/css; charset=utf-8",
            ".html": "text/html; charset=utf-8",
            ".js": "text/javascript; charset=utf-8"
        }[extname(filePath)] ?? "application/octet-stream";
        response.writeHead(200, {
            "Content-Type": contentType,
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff"
        });
        response.end(content);
    } catch {
        sendJSON(response, 404, { error: "未找到页面。" });
    }
}

function sendJSON(response, status, payload) {
    response.writeHead(status, {
        "Content-Type": "application/json; charset=utf-8",
        "Cache-Control": "no-store",
        "X-Content-Type-Options": "nosniff"
    });
    response.end(JSON.stringify(payload));
}

function requiredText(value, label) {
    const text = normalizedOptionalText(value);
    if (!text) {
        throw new RequestError(400, `请填写${label}。`);
    }
    if (text.length > 80) {
        throw new RequestError(400, `${label}过长。`);
    }
    return text;
}

function normalizedOptionalText(value) {
    return typeof value === "string" ? value.trim() : "";
}

function positiveInteger(value, label) {
    const number = Number(value);
    if (!Number.isSafeInteger(number) || number <= 0 || number > 1_000_000_000) {
        throw new RequestError(400, `${label}必须是 1 到 1,000,000,000 的整数。`);
    }
    return number;
}

function lowStockThreshold(database) {
    const row = database.prepare(
        "SELECT value FROM application_settings WHERE name = ?"
    ).get("lowStockThreshold");
    return Number(row?.value ?? 7000);
}

class RequestError extends Error {
    constructor(status, message) {
        super(message);
        this.status = status;
    }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    const port = Number(process.env.PORT ?? 8786);
    const dataPath = process.env.DATA_PATH ?? "/data/bean-warehouse.sqlite";
    const publicPath = process.env.PUBLIC_PATH ?? join(process.cwd(), "public");
    createBeanWarehouseServer({ dataPath, publicPath }).listen(port, "0.0.0.0", () => {
        console.log(`Bean Warehouse is listening on port ${port}.`);
    });
}
