import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { createBeanWarehouseServer } from "../server/server.mjs";

test("inbound, outbound and duplicate submission rebuild the expected balance", async (testContext) => {
  const directory = await mkdtemp(join(tmpdir(), "bean-warehouse-"));
  const server = createBeanWarehouseServer({
    dataPath: join(directory, "inventory.sqlite"),
    publicPath: join(process.cwd(), "public")
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  const baseURL = `http://127.0.0.1:${address.port}`;
  testContext.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await rm(directory, { recursive: true, force: true });
  });

  const inbound = {
    brandID: "Perler",
    seriesID: "Standard",
    colorCode: "F22",
    kind: "inbound",
    quantity: 100,
    idempotencyKey: "inbound-1"
  };
  assert.equal((await post(baseURL, inbound)).status, 201);
  assert.equal((await post(baseURL, inbound)).status, 201);
  assert.equal((await post(baseURL, { ...inbound, kind: "outbound", quantity: 35, idempotencyKey: "outbound-1" })).status, 201);

  const inventory = await (await fetch(`${baseURL}/api/inventory`)).json();
  assert.equal(inventory.items.length, 1);
  assert.equal(inventory.items[0].onHand, 65);
  assert.equal(inventory.items[0].available, 65);
});

test("outbound above available stock is rejected", async (testContext) => {
  const directory = await mkdtemp(join(tmpdir(), "bean-warehouse-"));
  const server = createBeanWarehouseServer({
    dataPath: join(directory, "inventory.sqlite"),
    publicPath: join(process.cwd(), "public")
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const address = server.address();
  const baseURL = `http://127.0.0.1:${address.port}`;
  testContext.after(async () => {
    await new Promise((resolve) => server.close(resolve));
    await rm(directory, { recursive: true, force: true });
  });

  const response = await post(baseURL, {
    brandID: "Perler",
    seriesID: "Standard",
    colorCode: "F22",
    kind: "outbound",
    quantity: 1,
    idempotencyKey: "outbound-1"
  });
  assert.equal(response.status, 409);
  assert.match((await response.json()).error, /可用库存仅 0/);
});

function post(baseURL, payload) {
  return fetch(`${baseURL}/api/movements`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
}
