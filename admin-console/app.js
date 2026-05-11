import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const config = window.SEASON_ADMIN_CONFIG ?? {};
const requiredConfig = ["supabaseUrl", "supabaseAnonKey"];
const isConfigured = requiredConfig.every((key) => {
  const value = config[key];
  return typeof value === "string" && value.length > 0 && !value.includes("paste-");
});

const state = {
  client: null,
  session: null,
  inbox: null,
  selected: null
};

const elements = {
  environmentLabel: document.querySelector("#environmentLabel"),
  configWarning: document.querySelector("#configWarning"),
  authPanel: document.querySelector("#authPanel"),
  appPanel: document.querySelector("#appPanel"),
  loginForm: document.querySelector("#loginForm"),
  emailInput: document.querySelector("#emailInput"),
  passwordInput: document.querySelector("#passwordInput"),
  sessionEmail: document.querySelector("#sessionEmail"),
  signOutButton: document.querySelector("#signOutButton"),
  refreshButton: document.querySelector("#refreshButton"),
  statusesInput: document.querySelector("#statusesInput"),
  limitInput: document.querySelector("#limitInput"),
  syncStatus: document.querySelector("#syncStatus"),
  totalCount: document.querySelector("#totalCount"),
  needsReviewCount: document.querySelector("#needsReviewCount"),
  validatedCount: document.querySelector("#validatedCount"),
  failedCount: document.querySelector("#failedCount"),
  proposalList: document.querySelector("#proposalList"),
  proposalDetail: document.querySelector("#proposalDetail")
};

init();

async function init() {
  elements.environmentLabel.textContent = config.environmentLabel ?? "Not configured";
  elements.configWarning.hidden = isConfigured;
  elements.authPanel.hidden = false;
  elements.appPanel.hidden = true;
  elements.signOutButton.hidden = true;
  elements.statusesInput.value = (config.defaultStatuses ?? [
    "needs_human_review",
    "draft",
    "failed_validation",
    "queued_for_validation",
    "validated"
  ]).join(", ");
  elements.limitInput.value = String(config.defaultLimit ?? 25);

  if (!isConfigured) {
    elements.loginForm.querySelectorAll("input, button").forEach((control) => {
      control.disabled = true;
    });
    elements.sessionEmail.textContent = "Config required";
    setStatus("Missing local config.");
    return;
  }

  state.client = createClient(config.supabaseUrl, config.supabaseAnonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false
    }
  });

  bindEvents();

  const { data, error } = await state.client.auth.getSession();
  if (error) {
    setStatus(error.message, "error");
    return;
  }

  state.session = data.session;
  renderSession();

  if (state.session) {
    await loadInbox();
  }
}

function bindEvents() {
  elements.loginForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    await signIn();
  });

  elements.signOutButton.addEventListener("click", async () => {
    await state.client.auth.signOut();
    state.session = null;
    state.inbox = null;
    state.selected = null;
    renderSession();
  });

  elements.refreshButton.addEventListener("click", loadInbox);
}

async function signIn() {
  setStatus("Signing in...");
  const email = elements.emailInput.value.trim();
  const password = elements.passwordInput.value;
  const { data, error } = await state.client.auth.signInWithPassword({ email, password });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  state.session = data.session;
  renderSession();
  await loadInbox();
}

function renderSession() {
  const email = state.session?.user?.email ?? "Signed out";
  elements.sessionEmail.textContent = email;
  elements.signOutButton.hidden = !state.session;
  elements.authPanel.hidden = Boolean(state.session);
  elements.appPanel.hidden = !state.session;
}

async function loadInbox() {
  if (!state.session) return;

  setStatus("Loading review inbox...");
  const statuses = parseCSV(elements.statusesInput.value);
  const limit = clampNumber(Number(elements.limitInput.value), 1, 100, config.defaultLimit ?? 25);

  const { data, error } = await state.client.rpc("get_catalog_agent_review_inbox", {
    p_statuses: statuses,
    p_proposal_type: null,
    p_risk_levels: null,
    p_source_domain: null,
    p_limit: limit,
    p_offset: 0
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  state.inbox = data;
  state.selected = Array.isArray(data?.items) ? data.items[0] ?? null : null;
  renderInbox();
  setStatus(`Loaded ${data?.items?.length ?? 0} proposals.`);
}

function renderInbox() {
  const items = Array.isArray(state.inbox?.items) ? state.inbox.items : [];
  const counts = state.inbox?.metadata?.counts ?? {};
  const byStatus = counts.by_status ?? {};

  elements.totalCount.textContent = String(counts.total ?? items.length);
  elements.needsReviewCount.textContent = String(byStatus.needs_human_review ?? 0);
  elements.validatedCount.textContent = String(byStatus.validated ?? 0);
  elements.failedCount.textContent = String(byStatus.failed_validation ?? 0);

  elements.proposalList.replaceChildren(...items.map(renderProposalRow));
  renderSelectedProposal();
}

function renderProposalRow(item) {
  const proposal = item.proposal ?? {};
  const button = document.createElement("button");
  button.type = "button";
  button.className = `proposal-row ${state.selected?.proposal_id === item.proposal_id ? "selected" : ""}`;
  button.addEventListener("click", () => {
    state.selected = item;
    renderInbox();
  });

  button.innerHTML = `
    <div class="row-title">
      <strong>${escapeHTML(proposal.normalized_text ?? "Untitled")}</strong>
      <span>#${escapeHTML(item.proposal_id)}</span>
    </div>
    <div class="badge-line">
      ${badge(proposal.status)}
      ${badge(proposal.risk_level)}
      ${badge(proposal.proposal_type)}
    </div>
    <div class="row-meta">
      <span>${escapeHTML(formatDate(proposal.created_at))}</span>
      <span>${escapeHTML(proposal.confidence_score ?? "no confidence")}</span>
    </div>
  `;

  return button;
}

function renderSelectedProposal() {
  const item = state.selected;
  if (!item) {
    elements.proposalDetail.innerHTML = `
      <div class="empty-state">
        <h2>No proposals</h2>
        <p>The current filters returned no agent proposals.</p>
      </div>
    `;
    return;
  }

  const proposal = item.proposal ?? {};
  const target = item.target ?? {};
  const proposed = item.proposed ?? {};

  elements.proposalDetail.innerHTML = `
    <div class="detail-stack">
      <header class="detail-header">
        <h2>${escapeHTML(proposal.normalized_text ?? "Untitled")}</h2>
        <div class="badge-line">
          ${badge(proposal.status)}
          ${badge(proposal.risk_level)}
          ${badge(proposal.proposal_type)}
          ${proposal.auto_apply_eligible ? badge("auto_apply_eligible") : ""}
        </div>
      </header>

      <section class="detail-section">
        <h3>Target and proposal</h3>
        <div class="detail-grid">
          ${detailCell("Target slug", target.slug ?? proposed.target_slug)}
          ${detailCell("Target id", target.ingredient_id)}
          ${detailCell("Alias text", proposed.proposed_alias_text)}
          ${detailCell("Localized name", proposed.proposed_localized_name)}
          ${detailCell("Proposed slug", proposed.proposed_slug)}
          ${detailCell("Language", proposed.proposed_language_code)}
        </div>
      </section>

      <section class="detail-section">
        <h3>Rationale</h3>
        <p>${escapeHTML(proposal.rationale ?? "No rationale.")}</p>
      </section>

      <section class="detail-section">
        <h3>Actions</h3>
        <div class="review-note">
          <textarea id="reviewNote" placeholder="Reviewer note, required for reject and useful for learning memory."></textarea>
          <div class="action-row">
            <button type="button" data-action="queue">Queue validation</button>
            <button type="button" data-action="validate">Validate</button>
            <button type="button" data-action="apply">Apply if safe</button>
            <button type="button" data-action="more" class="secondary">More evidence</button>
            <button type="button" data-action="reject" class="danger">Reject</button>
            <button type="button" data-action="learning" class="secondary">Load learning</button>
          </div>
        </div>
      </section>

      <section class="detail-section">
        <h3>Validation errors</h3>
        ${jsonBlock(proposal.validation_errors ?? [])}
      </section>

      <section class="detail-section">
        <h3>Evidence</h3>
        ${jsonBlock(proposal.evidence ?? [])}
      </section>

      <section class="detail-section">
        <h3>Recent events</h3>
        ${jsonBlock(item.recent_events ?? [])}
      </section>

      <section class="detail-section" id="learningPanel">
        <h3>Learning memory</h3>
        <p>Use “Load learning” to fetch current term memory.</p>
      </section>
    </div>
  `;

  elements.proposalDetail.querySelector('[data-action="queue"]').addEventListener("click", () => reviewProposal("queue_for_validation"));
  elements.proposalDetail.querySelector('[data-action="more"]').addEventListener("click", () => reviewProposal("request_more_evidence"));
  elements.proposalDetail.querySelector('[data-action="reject"]').addEventListener("click", () => reviewProposal("reject"));
  elements.proposalDetail.querySelector('[data-action="validate"]').addEventListener("click", validateProposal);
  elements.proposalDetail.querySelector('[data-action="apply"]').addEventListener("click", applyProposal);
  elements.proposalDetail.querySelector('[data-action="learning"]').addEventListener("click", loadLearningMemory);
}

async function reviewProposal(action) {
  const note = elements.proposalDetail.querySelector("#reviewNote")?.value?.trim() ?? "";
  if (action === "reject" && !note) {
    setStatus("Reject requires a reviewer note.", "error");
    return;
  }

  setStatus(`Review action: ${action}...`);
  const { error } = await state.client.rpc("review_catalog_agent_proposal", {
    p_proposal_id: state.selected.proposal_id,
    p_action: action,
    p_reviewer_note: note || null
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  await loadInbox();
}

async function validateProposal() {
  setStatus("Running deterministic validation...");
  const { error } = await state.client.rpc("validate_catalog_agent_proposal", {
    p_proposal_id: state.selected.proposal_id
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  await loadInbox();
}

async function applyProposal() {
  setStatus("Applying validated proposal through governed RPC...");
  const { error } = await state.client.rpc("apply_catalog_agent_proposal", {
    p_proposal_id: state.selected.proposal_id
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  await loadInbox();
}

async function loadLearningMemory() {
  const text = state.selected?.proposal?.normalized_text;
  if (!text) return;

  setStatus(`Loading learning memory for ${text}...`);
  const { data, error } = await state.client.rpc("get_catalog_agent_learning_context", {
    p_normalized_texts: [text],
    p_limit_per_term: 5
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  const panel = elements.proposalDetail.querySelector("#learningPanel");
  panel.innerHTML = `
    <h3>Learning memory</h3>
    ${jsonBlock(data)}
  `;
  setStatus(`Loaded learning memory for ${text}.`);
}

function detailCell(label, value) {
  return `
    <div>
      <span>${escapeHTML(label)}</span>
      <strong>${escapeHTML(value ?? "none")}</strong>
    </div>
  `;
}

function badge(value) {
  const normalized = String(value ?? "unknown");
  return `<span class="badge ${escapeHTML(normalized)}">${escapeHTML(normalized)}</span>`;
}

function jsonBlock(value) {
  return `<pre class="json-block">${escapeHTML(JSON.stringify(value, null, 2))}</pre>`;
}

function parseCSV(value) {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function setStatus(message, level = "info") {
  elements.syncStatus.textContent = message;
  elements.syncStatus.dataset.level = level;
}

function clampNumber(value, min, max, fallback) {
  if (!Number.isFinite(value)) return fallback;
  return Math.min(max, Math.max(min, Math.floor(value)));
}

function formatDate(value) {
  if (!value) return "no date";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeStyle: "short"
  }).format(date);
}

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
