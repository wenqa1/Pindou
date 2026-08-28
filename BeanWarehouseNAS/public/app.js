const state = { inventory: null, movements: [] };

const movementForm = document.querySelector("#movement-form");
const thresholdForm = document.querySelector("#threshold-form");
const formMessage = document.querySelector("#form-message");
const inventoryMessage = document.querySelector("#inventory-message");

document.querySelector("#refresh-button").addEventListener("click", () => refresh());
movementForm.addEventListener("submit", submitMovement);
thresholdForm.addEventListener("submit", submitThreshold);

await refresh();

async function refresh() {
  setMessage(inventoryMessage, "正在刷新…");
  try {
    const [inventory, movements] = await Promise.all([
      request("/api/inventory"),
      request("/api/movements")
    ]);
    state.inventory = inventory;
    state.movements = movements.movements;
    document.querySelector("#threshold-input").value = inventory.lowStockThreshold;
    renderSummary(inventory);
    renderInventory(inventory.items);
    renderMovements(movements.movements);
    setMessage(inventoryMessage, "");
  } catch (error) {
    setMessage(inventoryMessage, error.message, true);
  }
}

async function submitMovement(event) {
  event.preventDefault();
  const formData = new FormData(movementForm);
  const payload = Object.fromEntries(formData.entries());
  payload.quantity = Number(payload.quantity);
  payload.idempotencyKey = crypto.randomUUID();
  setMessage(formMessage, "正在保存…");

  try {
    await request("/api/movements", { method: "POST", body: JSON.stringify(payload) });
    movementForm.reset();
    setMessage(formMessage, "已保存流水。");
    await refresh();
  } catch (error) {
    setMessage(formMessage, error.message, true);
  }
}

async function submitThreshold(event) {
  event.preventDefault();
  const threshold = Number(document.querySelector("#threshold-input").value);
  try {
    await request("/api/settings", {
      method: "PUT",
      body: JSON.stringify({ lowStockThreshold: threshold })
    });
    await refresh();
  } catch (error) {
    setMessage(inventoryMessage, error.message, true);
  }
}

async function request(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers ?? {}) }
  });
  const payload = await response.json();
  if (!response.ok) throw new Error(payload.error ?? "请求失败。");
  return payload;
}

function renderSummary(inventory) {
  const cards = [
    ["现存", inventory.totals.onHand],
    ["可用", inventory.totals.available],
    ["低库存", inventory.totals.lowStockCount]
  ];
  const root = document.querySelector("#summary");
  root.replaceChildren(...cards.map(([label, value]) => metricCard(label, value)));
}

function renderInventory(items) {
  const root = document.querySelector("#inventory-list");
  if (!items.length) {
    root.replaceChildren(emptyState("还没有库存", "新增一次入库后，这里会显示所有色号。"));
    return;
  }
  root.replaceChildren(...items.map((item) => {
    const card = document.createElement("article");
    card.className = "sku-card";
    const title = document.createElement("h3");
    title.textContent = item.colorCode;
    const description = document.createElement("p");
    description.textContent = `${item.brandID} · ${item.seriesID}`;
    const quantity = document.createElement("strong");
    quantity.textContent = `可用 ${formatNumber(item.available)}`;
    card.append(title, description, quantity);
    if (item.lowStock) {
      const badge = document.createElement("span");
      badge.className = "low-stock";
      badge.textContent = "低于阈值";
      card.append(badge);
    }
    return card;
  }));
}

function renderMovements(movements) {
  const root = document.querySelector("#movement-list");
  if (!movements.length) {
    root.replaceChildren(emptyState("还没有流水", "入库和出库记录会显示在这里。"));
    return;
  }
  root.replaceChildren(...movements.map((movement) => {
    const row = document.createElement("article");
    row.className = "movement-row";
    const meta = document.createElement("div");
    const title = document.createElement("strong");
    title.textContent = movementTitle(movement.kind);
    const description = document.createElement("p");
    description.textContent = `${movement.brandID} · ${movement.seriesID} · ${movement.colorCode}`;
    meta.append(title, description);
    const quantity = document.createElement("div");
    quantity.className = movement.kind === "outbound" ? "quantity outbound" : "quantity";
    quantity.textContent = `${movement.kind === "outbound" ? "−" : "+"}${formatNumber(movement.quantity)}`;
    const time = document.createElement("time");
    time.textContent = new Intl.DateTimeFormat("zh-CN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(movement.occurredAt));
    row.append(meta, quantity, time);
    return row;
  }));
}

function metricCard(label, value) {
  const card = document.createElement("article");
  card.className = "metric-card";
  const name = document.createElement("p");
  name.textContent = label;
  const amount = document.createElement("strong");
  amount.textContent = formatNumber(value);
  card.append(name, amount);
  return card;
}

function emptyState(title, description) {
  const node = document.createElement("div");
  node.className = "empty-state";
  const heading = document.createElement("strong");
  heading.textContent = title;
  const text = document.createElement("p");
  text.textContent = description;
  node.append(heading, text);
  return node;
}

function movementTitle(kind) {
  return { inbound: "入库", outbound: "出库", stocktakeIncrease: "盘盈", stocktakeDecrease: "盘亏", outboundReversal: "出库冲销", inboundReversal: "入库冲销" }[kind] ?? kind;
}

function formatNumber(value) {
  return new Intl.NumberFormat("zh-CN").format(value);
}

function setMessage(target, message, isError = false) {
  target.textContent = message;
  target.classList.toggle("error", isError);
}
