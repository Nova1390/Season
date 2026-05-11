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
  isAdmin: false,
  inbox: null,
  selected: null,
  learningMemory: null,
  operations: {
    summary: null,
    autoApplySummary: null,
    autoApplyDiagnostics: null,
    workerJobs: [],
    applyAudits: []
  }
};

const elements = {
  environmentLabel: document.querySelector("#environmentLabel"),
  configWarning: document.querySelector("#configWarning"),
  authPanel: document.querySelector("#authPanel"),
  appPanel: document.querySelector("#appPanel"),
  loginForm: document.querySelector("#loginForm"),
  emailInput: document.querySelector("#emailInput"),
  passwordInput: document.querySelector("#passwordInput"),
  authMessage: document.querySelector("#authMessage"),
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
  proposalDetail: document.querySelector("#proposalDetail"),
  refreshOpsButton: document.querySelector("#refreshOpsButton"),
  workerRunForm: document.querySelector("#workerRunForm"),
  workerNameInput: document.querySelector("#workerNameInput"),
  workerLimitInput: document.querySelector("#workerLimitInput"),
  workerSourceDomainInput: document.querySelector("#workerSourceDomainInput"),
  runWorkerButton: document.querySelector("#runWorkerButton"),
  workerRunResult: document.querySelector("#workerRunResult"),
  autoApplyDiagnostics: document.querySelector("#autoApplyDiagnostics"),
  agentRunsToday: document.querySelector("#agentRunsToday"),
  workerJobsToday: document.querySelector("#workerJobsToday"),
  llmTokensToday: document.querySelector("#llmTokensToday"),
  llmCostToday: document.querySelector("#llmCostToday"),
  autoAppliesToday: document.querySelector("#autoAppliesToday"),
  activeAppliesToday: document.querySelector("#activeAppliesToday"),
  revertedAppliesToday: document.querySelector("#revertedAppliesToday"),
  failedRevertsToday: document.querySelector("#failedRevertsToday"),
  workerJobsList: document.querySelector("#workerJobsList"),
  applyAuditList: document.querySelector("#applyAuditList")
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

  if (state.session) {
    await openAdminSession();
  } else {
    renderSession();
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
    state.isAdmin = false;
    state.inbox = null;
    state.selected = null;
    state.learningMemory = null;
    state.operations = { summary: null, autoApplySummary: null, autoApplyDiagnostics: null, workerJobs: [], applyAudits: [] };
    setAuthMessage("");
    renderSession();
  });

  elements.refreshButton.addEventListener("click", loadInbox);
  elements.refreshOpsButton.addEventListener("click", loadOperations);
  elements.workerRunForm.addEventListener("submit", runAgentWorker);
  elements.applyAuditList.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-rollback-audit-id]");
    if (!button) return;
    await rollbackApplyAudit(Number(button.dataset.rollbackAuditId));
  });
}

async function runAgentWorker(event) {
  event.preventDefault();
  if (!state.session || !state.isAdmin) return;

  const workerName = elements.workerNameInput.value;
  const limit = clampNumber(Number(elements.workerLimitInput.value), 1, 3, 1);
  const sourceDomain = elements.workerSourceDomainInput.value.trim() || null;
  const payload = buildWorkerPayload({ workerName, limit, sourceDomain });

  elements.runWorkerButton.disabled = true;
  renderWorkerRunResult({
    ok: true,
    status: "running",
    message: `Running ${workerName}...`
  });
  setStatus(`Running ${workerName}...`);

  const { data, error } = await state.client.functions.invoke("run-catalog-agent-orchestrator", {
    body: payload
  });

  elements.runWorkerButton.disabled = false;

  if (error) {
    renderWorkerRunResult({
      ok: false,
      status: "failed",
      message: error.message,
      details: error
    });
    setStatus(error.message, "error");
    await loadOperations({ silent: true });
    return;
  }

  renderWorkerRunResult({
    ok: data?.ok === true,
    status: data?.ok === true ? "completed" : "failed",
    message: data?.ok === true ? "Worker completed." : "Worker returned an error.",
    details: data
  });
  setStatus(data?.ok === true ? "Agent worker completed." : "Agent worker failed.", data?.ok === true ? "success" : "error");
  await loadOperations({ silent: true });
  await loadInbox({ keepProposalId: state.selected?.proposal_id });
}

function buildWorkerPayload({ workerName, limit, sourceDomain }) {
  if (workerName === "low_risk_apply_batch") {
    return {
      worker_name: "low_risk_apply_batch",
      action: "dry_run",
      limit,
      source_domain: sourceDomain,
      risk_ceiling: "low",
      dry_run: true,
      debug: false
    };
  }

  return {
    worker_name: "enrichment_draft_batch",
    action: "run",
    limit,
    source_domain: sourceDomain,
    risk_ceiling: "low",
    dry_run: false,
    debug: false
  };
}

function renderWorkerRunResult(result) {
  elements.workerRunResult.hidden = false;
  elements.workerRunResult.innerHTML = `
    <article class="worker-job ${result.ok ? "" : "audit-record"}">
      <header>
        <div>
          <strong>${escapeHTML(result.message)}</strong>
          <span>${escapeHTML(result.status)}</span>
        </div>
        <div class="badge-line">
          ${badge(result.status)}
        </div>
      </header>
      ${result.details ? jsonBlock(result.details) : ""}
    </article>
  `;
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
  elements.passwordInput.value = "";
  await openAdminSession();
}

function renderSession() {
  const hasAdminSession = Boolean(state.session && state.isAdmin);
  const email = state.session?.user?.email ?? "Signed out";
  elements.sessionEmail.textContent = email;
  elements.signOutButton.hidden = !hasAdminSession;
  elements.authPanel.hidden = hasAdminSession;
  elements.appPanel.hidden = !hasAdminSession;
}

async function openAdminSession() {
  renderSession();
  setAuthMessage("Checking catalog admin access...");

  const isAdmin = await verifyCatalogAdminAccess();
  if (!isAdmin) {
    const attemptedEmail = state.session?.user?.email ?? "this account";
    await state.client.auth.signOut();
    state.session = null;
    state.isAdmin = false;
    state.inbox = null;
    state.selected = null;
    state.learningMemory = null;
    state.operations = { summary: null, autoApplySummary: null, autoApplyDiagnostics: null, workerJobs: [], applyAudits: [] };
    renderSession();
    setAuthMessage(`${attemptedEmail} is not authorized for the catalog console.`, "error");
    setStatus("Access denied.");
    return;
  }

  state.isAdmin = true;
  renderSession();
  setAuthMessage("Catalog admin access confirmed.", "success");
  await loadInbox();
}

async function verifyCatalogAdminAccess() {
  if (!state.session) return false;

  const { data, error } = await state.client.rpc("is_current_user_catalog_admin");
  if (error) {
    setStatus(error.message, "error");
    return false;
  }

  return decodeAdminAccessResult(data);
}

async function loadInbox(options = {}) {
  if (!state.session) return;

  setStatus("Loading review inbox...");
  const previousSelectionId = Number(options.keepProposalId ?? state.selected?.proposal_id ?? 0);
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
  const items = Array.isArray(data?.items) ? data.items : [];
  state.selected = items.find((item) => Number(item.proposal_id) === previousSelectionId) ?? items[0] ?? null;
  if (!state.selected || Number(state.selected.proposal_id) !== previousSelectionId) {
    state.learningMemory = null;
  }
  renderInbox();
  setStatus(`Loaded ${data?.items?.length ?? 0} proposals.`);
  await loadOperations({ silent: true });
}

async function loadOperations(options = {}) {
  if (!state.session) return;
  if (!options.silent) {
    setStatus("Loading agent operations...");
  }

  const todayISO = new Intl.DateTimeFormat("en-CA").format(new Date());

  const [summaryResult, autoApplySummaryResult, diagnosticsResult, jobsResult, applyAuditsResult] = await Promise.all([
    state.client
      .from("catalog_agent_daily_automation_summary")
      .select("*")
      .eq("day", todayISO)
      .maybeSingle(),
    state.client
      .from("catalog_agent_auto_apply_audit_summary")
      .select("*")
      .eq("day", todayISO)
      .maybeSingle(),
    state.client.rpc("get_catalog_agent_auto_apply_diagnostics"),
    state.client
      .from("catalog_agent_worker_jobs")
      .select("id,agent_run_id,worker_name,worker_function,requested_action,status,risk_ceiling,item_limit,dry_run,summary,failure_reason,created_at,started_at,finished_at")
      .order("created_at", { ascending: false })
      .limit(10),
    state.client
      .from("catalog_agent_apply_audit")
      .select("id,proposal_id,run_id,worker_job_id,mutation_type,mutation_scope,apply_mode,actor_role,target_ingredient_id,status,rollback_plan,apply_note,revert_reason,applied_at,reverted_at")
      .order("applied_at", { ascending: false })
      .limit(10)
  ]);

  if (summaryResult.error) {
    setStatus(summaryResult.error.message, "error");
    return;
  }
  if (autoApplySummaryResult.error) {
    setStatus(autoApplySummaryResult.error.message, "error");
    return;
  }
  if (diagnosticsResult.error) {
    setStatus(diagnosticsResult.error.message, "error");
    return;
  }
  if (jobsResult.error) {
    setStatus(jobsResult.error.message, "error");
    return;
  }
  if (applyAuditsResult.error) {
    setStatus(applyAuditsResult.error.message, "error");
    return;
  }

  state.operations = {
    summary: summaryResult.data ?? null,
    autoApplySummary: autoApplySummaryResult.data ?? null,
    autoApplyDiagnostics: diagnosticsResult.data ?? null,
    workerJobs: Array.isArray(jobsResult.data) ? jobsResult.data : [],
    applyAudits: Array.isArray(applyAuditsResult.data) ? applyAuditsResult.data : []
  };
  renderOperations();
  if (!options.silent) {
    setStatus("Agent operations loaded.", "success");
  }
}

function renderOperations() {
  const summary = state.operations.summary ?? {};
  const autoApplySummary = state.operations.autoApplySummary ?? {};
  const diagnostics = state.operations.autoApplyDiagnostics ?? {};
  const jobs = state.operations.workerJobs ?? [];
  const applyAudits = state.operations.applyAudits ?? [];

  elements.agentRunsToday.textContent = String(summary.agent_runs ?? 0);
  elements.workerJobsToday.textContent = String(summary.worker_jobs ?? 0);
  elements.llmTokensToday.textContent = formatNumber(summary.total_tokens ?? 0);
  elements.llmCostToday.textContent = formatCurrency(summary.estimated_cost_usd ?? 0);
  elements.autoAppliesToday.textContent = String(autoApplySummary.total_auto_apply_records ?? 0);
  elements.activeAppliesToday.textContent = String(autoApplySummary.active_applies ?? 0);
  elements.revertedAppliesToday.textContent = String(autoApplySummary.reverted_applies ?? 0);
  elements.failedRevertsToday.textContent = String(autoApplySummary.failed_reverts ?? 0);
  renderAutoApplyDiagnostics(diagnostics);

  if (jobs.length === 0) {
    elements.workerJobsList.innerHTML = "<p>No worker jobs yet. The agent has not delegated Autopilot work today.</p>";
  } else {
    elements.workerJobsList.innerHTML = jobs.map((job) => `
      <article class="worker-job">
        <header>
          <div>
            <strong>${escapeHTML(job.worker_name)}</strong>
            <span>${escapeHTML(job.worker_function)}</span>
          </div>
          <div class="badge-line">
            ${badge(job.status)}
            ${badge(job.risk_ceiling)}
            ${job.dry_run ? badge("dry_run") : ""}
          </div>
        </header>
        <div class="worker-job-meta">
          <span>Job #${escapeHTML(job.id)}</span>
          <span>Run #${escapeHTML(job.agent_run_id ?? "none")}</span>
          <span>Limit ${escapeHTML(job.item_limit)}</span>
          <span>${escapeHTML(formatDate(job.created_at))}</span>
        </div>
        ${job.failure_reason ? `<p class="inline-error">${escapeHTML(job.failure_reason)}</p>` : ""}
        ${jsonBlock(job.summary ?? {})}
      </article>
    `).join("");
  }

  if (applyAudits.length === 0) {
    elements.applyAuditList.innerHTML = "<p>No auto-apply audit records yet. Autonomous apply is still gated.</p>";
    return;
  }

  elements.applyAuditList.innerHTML = applyAudits.map((audit) => `
    <article class="worker-job audit-record">
      <header>
        <div>
          <strong>${escapeHTML(audit.mutation_type)}</strong>
          <span>${escapeHTML(audit.mutation_scope)}</span>
        </div>
        <div class="badge-line">
          ${badge(audit.status)}
          ${badge(audit.apply_mode)}
        </div>
      </header>
      <div class="worker-job-meta">
        <span>Audit #${escapeHTML(audit.id)}</span>
        <span>Proposal #${escapeHTML(audit.proposal_id)}</span>
        <span>Run #${escapeHTML(audit.run_id ?? "none")}</span>
        <span>${escapeHTML(formatDate(audit.applied_at))}</span>
      </div>
      ${audit.revert_reason ? `<p>${escapeHTML(audit.revert_reason)}</p>` : ""}
      <div class="audit-actions">
        ${rollbackButton(audit)}
      </div>
      ${jsonBlock({
        rollback_plan: audit.rollback_plan,
        worker_job_id: audit.worker_job_id,
        target_ingredient_id: audit.target_ingredient_id,
        reverted_at: audit.reverted_at
      })}
    </article>
  `).join("");
}

function renderAutoApplyDiagnostics(diagnostics) {
  if (!diagnostics?.ok) {
    elements.autoApplyDiagnostics.innerHTML = "<p>Auto-apply diagnostics are not loaded yet.</p>";
    return;
  }

  const counts = diagnostics.counts ?? {};
  const readyCount = Number(diagnostics.ready_for_low_risk_apply ?? 0);
  const readyPreview = Array.isArray(diagnostics.ready_preview) ? diagnostics.ready_preview : [];

  elements.autoApplyDiagnostics.innerHTML = `
    <article class="worker-job">
      <header>
        <div>
          <strong>Low-risk apply readiness</strong>
          <span>${escapeHTML(diagnostics.explanation ?? "No explanation available.")}</span>
        </div>
        <div class="badge-line">
          ${badge(`${readyCount}_ready`)}
        </div>
      </header>
      <div class="diagnostic-grid">
        ${diagnosticCell("Ready", readyCount)}
        ${diagnosticCell("Draft", counts.draft)}
        ${diagnosticCell("Queued", counts.queued_for_validation)}
        ${diagnosticCell("Needs review", counts.needs_human_review)}
        ${diagnosticCell("Failed validation", counts.failed_validation)}
        ${diagnosticCell("Validated total", counts.validated_total)}
        ${diagnosticCell("Not eligible", counts.validated_not_auto_apply_eligible)}
        ${diagnosticCell("Auto-applied", counts.auto_applied)}
      </div>
      ${readyPreview.length > 0 ? jsonBlock({ ready_preview: readyPreview }) : ""}
    </article>
  `;
}

async function rollbackApplyAudit(applyAuditId) {
  if (!Number.isFinite(applyAuditId) || applyAuditId <= 0) {
    setStatus("Invalid audit id.", "error");
    return;
  }

  const audit = state.operations.applyAudits.find((item) => Number(item.id) === applyAuditId);
  if (!audit || audit.status !== "applied") {
    setStatus("Only active applied audit records can be rolled back.", "error");
    return;
  }

  const confirmed = window.confirm(
    `Rollback auto-apply audit #${applyAuditId}? This will revert only if the current catalog row still matches the audited after-state.`
  );
  if (!confirmed) return;

  const reason = window.prompt("Rollback reason, required for audit history:");
  const normalizedReason = String(reason ?? "").trim();
  if (!normalizedReason) {
    setStatus("Rollback cancelled: a reason is required.", "error");
    return;
  }

  setStatus(`Rolling back audit #${applyAuditId}...`);
  const { data, error } = await state.client.rpc("rollback_catalog_agent_apply", {
    p_apply_audit_id: applyAuditId,
    p_revert_reason: normalizedReason
  });

  if (error) {
    setStatus(error.message, "error");
    await loadOperations({ silent: true });
    return;
  }

  if (data?.ok === false) {
    setStatus(data.error ?? "Rollback failed and was recorded.", "error");
  } else {
    setStatus(`Rollback completed for audit #${applyAuditId}.`, "success");
  }

  await loadOperations({ silent: true });
  await loadInbox({ keepProposalId: audit.proposal_id });
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
  const actionState = getProposalActionState(proposal);

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
        <p class="action-guidance">${escapeHTML(actionState.guidance)}</p>
        <div class="review-note">
          <textarea id="reviewNote" placeholder="Reviewer note, required for reject and useful for learning memory."></textarea>
          <div class="action-row">
            ${actionButton("queue", "Queue validation", actionState.queue)}
            ${actionButton("validate", "Validate", actionState.validate)}
            ${actionButton("apply", "Apply if safe", actionState.apply)}
            ${actionButton("more", "More evidence", actionState.more, "secondary")}
            ${actionButton("reject", "Reject", actionState.reject, "danger")}
            ${actionButton("learning", "Load learning", actionState.learning, "secondary")}
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

  bindEnabledAction("queue", () => reviewProposal("queue_for_validation"));
  bindEnabledAction("more", () => reviewProposal("request_more_evidence"));
  bindEnabledAction("reject", () => reviewProposal("reject"));
  bindEnabledAction("validate", validateProposal);
  bindEnabledAction("apply", applyProposal);
  bindEnabledAction("learning", loadLearningMemory);
}

async function reviewProposal(action) {
  const note = elements.proposalDetail.querySelector("#reviewNote")?.value?.trim() ?? "";
  if (action === "reject" && !note) {
    setStatus("Reject requires a reviewer note.", "error");
    return;
  }

  setStatus(`Review action: ${action}...`);
  const proposalId = state.selected.proposal_id;
  const { error } = await state.client.rpc("review_catalog_agent_proposal", {
    p_proposal_id: proposalId,
    p_action: action,
    p_reviewer_note: note || null
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  state.learningMemory = null;
  await loadInbox({ keepProposalId: proposalId });
  if (action === "request_more_evidence") {
    await loadLearningMemory({ silent: true });
    setStatus("More evidence saved and learning memory updated.", "success");
  } else {
    setStatus(`Review action saved: ${action}.`, "success");
  }
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

async function loadLearningMemory(options = {}) {
  const text = state.selected?.proposal?.normalized_text;
  if (!text) return;

  const panel = elements.proposalDetail.querySelector("#learningPanel");
  if (panel && !options.silent) {
    panel.innerHTML = `
      <h3>Learning memory</h3>
      <p>Loading learning memory for ${escapeHTML(text)}...</p>
    `;
    panel.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  if (!options.silent) {
    setStatus(`Loading learning memory for ${text}...`);
  }
  const { data, error } = await state.client.rpc("get_catalog_agent_learning_context", {
    p_normalized_texts: [text],
    p_limit_per_term: 5
  });

  if (error) {
    if (panel && !options.silent) {
      panel.innerHTML = `
        <h3>Learning memory</h3>
        <p class="inline-error">${escapeHTML(error.message)}</p>
      `;
    }
    setStatus(error.message, "error");
    return;
  }

  state.learningMemory = data;
  if (panel) {
    panel.innerHTML = `
      <h3>Learning memory</h3>
      ${learningMemorySummary(data)}
      ${jsonBlock(data)}
    `;
    if (!options.silent) {
      panel.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }
  if (!options.silent) {
    setStatus(`Loaded learning memory for ${text}.`);
  }
}

function detailCell(label, value) {
  return `
    <div>
      <span>${escapeHTML(label)}</span>
      <strong>${escapeHTML(value ?? "none")}</strong>
    </div>
  `;
}

function diagnosticCell(label, value) {
  return `
    <div>
      <span>${escapeHTML(label)}</span>
      <strong>${escapeHTML(value ?? 0)}</strong>
    </div>
  `;
}

function getProposalActionState(proposal) {
  const status = String(proposal.status ?? "");
  const proposalType = String(proposal.proposal_type ?? "");
  const riskLevel = String(proposal.risk_level ?? "");
  const actionableTypes = ["approve_alias", "add_localization", "create_canonical"];
  const applyTypes = ["approve_alias", "add_localization"];
  const isClosed = ["applied", "rejected", "superseded"].includes(status);
  const canQueue = !isClosed
    && ["draft", "needs_human_review", "failed_validation"].includes(status)
    && actionableTypes.includes(proposalType);
  const canValidate = status === "queued_for_validation" && actionableTypes.includes(proposalType);
  const canApply = status === "validated"
    && riskLevel === "low"
    && applyTypes.includes(proposalType);
  const canRequestMore = !isClosed;
  const canReject = !isClosed;

  return {
    guidance: actionGuidance({
      status,
      proposalType,
      riskLevel,
      canQueue,
      canValidate,
      canApply
    }),
    queue: {
      enabled: canQueue,
      reason: canQueue ? "" : "Only actionable proposal types can be queued for validation."
    },
    validate: {
      enabled: canValidate,
      reason: canValidate ? "" : "Validation runs only after a proposal is queued and actionable."
    },
    apply: {
      enabled: canApply,
      reason: canApply ? "" : "Apply requires validated, low-risk approve_alias or add_localization."
    },
    more: {
      enabled: canRequestMore,
      reason: canRequestMore ? "" : "Closed proposals cannot request more evidence."
    },
    reject: {
      enabled: canReject,
      reason: canReject ? "" : "Closed proposals cannot be rejected again."
    },
    learning: {
      enabled: true,
      reason: ""
    }
  };
}

function actionGuidance(input) {
  if (input.proposalType === "needs_human_review") {
    return "This is a triage outcome, not an applicable catalog change. Use More evidence, Reject, or Load learning.";
  }
  if (input.status === "failed_validation") {
    return "This proposal failed deterministic validation. Review the errors before re-queueing.";
  }
  if (input.canApply) {
    return "This proposal passed validation and is low risk. Apply is available, but still review the target first.";
  }
  if (input.canValidate) {
    return "This proposal is queued. Run validation before any apply decision.";
  }
  if (input.canQueue) {
    return "This proposal can be queued for deterministic validation.";
  }
  return "Review the proposal status, type, and risk before choosing an action.";
}

function actionButton(action, label, state, variant = "") {
  const classes = [variant].filter(Boolean).join(" ");
  const disabled = state.enabled ? "" : "disabled";
  const title = state.reason ? ` title="${escapeHTML(state.reason)}"` : "";
  return `<button type="button" data-action="${escapeHTML(action)}" class="${escapeHTML(classes)}" ${disabled}${title}>${escapeHTML(label)}</button>`;
}

function rollbackButton(audit) {
  if (audit.status !== "applied") {
    return `<button type="button" class="secondary" disabled>Rollback unavailable</button>`;
  }

  return `
    <button type="button" class="danger" data-rollback-audit-id="${escapeHTML(audit.id)}">
      Rollback
    </button>
  `;
}

function bindEnabledAction(action, handler) {
  const button = elements.proposalDetail.querySelector(`[data-action="${action}"]`);
  if (!button || button.disabled) return;
  button.addEventListener("click", handler);
}

function badge(value) {
  const normalized = String(value ?? "unknown");
  return `<span class="badge ${escapeHTML(normalized)}">${escapeHTML(normalized)}</span>`;
}

function jsonBlock(value) {
  return `<pre class="json-block">${escapeHTML(JSON.stringify(value, null, 2))}</pre>`;
}

function learningMemorySummary(value) {
  const metadata = value?.metadata ?? {};
  const termLearnings = value?.term_learnings ?? {};
  const totalTermLearnings = Object.values(termLearnings)
    .filter(Array.isArray)
    .reduce((total, items) => total + items.length, 0);
  return `
    <p class="learning-summary">
      ${escapeHTML(totalTermLearnings)} term lessons, ${escapeHTML(metadata.terms_with_learning ?? 0)} terms with learning.
    </p>
  `;
}

function parseCSV(value) {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function decodeAdminAccessResult(value) {
  if (typeof value === "boolean") return value;
  if (Array.isArray(value)) return value.some(decodeAdminAccessResult);
  if (value && typeof value === "object") {
    if ("is_current_user_catalog_admin" in value) {
      return value.is_current_user_catalog_admin === true;
    }
  }
  return false;
}

function setStatus(message, level = "info") {
  elements.syncStatus.textContent = message;
  elements.syncStatus.dataset.level = level;
}

function setAuthMessage(message, level = "info") {
  elements.authMessage.textContent = message;
  elements.authMessage.dataset.level = level;
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

function formatNumber(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return "0";
  return new Intl.NumberFormat("en").format(parsed);
}

function formatCurrency(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return "$0";
  return new Intl.NumberFormat("en", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 4
  }).format(parsed);
}

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
