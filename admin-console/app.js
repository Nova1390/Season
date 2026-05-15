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
  draftsByText: new Map(),
  learningMemory: null,
  operations: {
    summary: null,
    autoApplySummary: null,
    autoApplyDiagnostics: null,
    scheduleStatus: null,
    scheduleGuard: null,
    latestDigest: null,
    scheduleShiftHealth: null,
    scheduleShiftRuns: [],
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
  latestOnlyInput: document.querySelector("#latestOnlyInput"),
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
  workerRunHint: document.querySelector("#workerRunHint"),
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
  scheduleDigestStatus: document.querySelector("#scheduleDigestStatus"),
  scheduleGuardState: document.querySelector("#scheduleGuardState"),
  scheduleKillSwitch: document.querySelector("#scheduleKillSwitch"),
  scheduleAnomalyCount: document.querySelector("#scheduleAnomalyCount"),
  scheduleLatestDigest: document.querySelector("#scheduleLatestDigest"),
  scheduleShiftHealth: document.querySelector("#scheduleShiftHealth"),
  scheduleShiftRunsToday: document.querySelector("#scheduleShiftRunsToday"),
  scheduleWindowStatus: document.querySelector("#scheduleWindowStatus"),
  scheduleNextAction: document.querySelector("#scheduleNextAction"),
  scheduleWindowMessage: document.querySelector("#scheduleWindowMessage"),
  scheduleShiftMessage: document.querySelector("#scheduleShiftMessage"),
  scheduleAnomalyList: document.querySelector("#scheduleAnomalyList"),
  scheduleShiftRunsList: document.querySelector("#scheduleShiftRunsList"),
  workerJobsList: document.querySelector("#workerJobsList"),
  applyAuditList: document.querySelector("#applyAuditList")
};

const tooltip = {
  node: null,
  activeTarget: null
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
    state.draftsByText = new Map();
    state.learningMemory = null;
    state.operations = {
      summary: null,
      autoApplySummary: null,
      autoApplyDiagnostics: null,
      scheduleStatus: null,
      scheduleGuard: null,
      latestDigest: null,
      scheduleShiftHealth: null,
      scheduleShiftRuns: [],
      workerJobs: [],
      applyAudits: []
    };
    setAuthMessage("");
    renderSession();
  });

  elements.refreshButton.addEventListener("click", loadInbox);
  elements.refreshOpsButton.addEventListener("click", loadOperations);
  elements.latestOnlyInput?.addEventListener("change", () => {
    state.learningMemory = null;
    renderInbox();
  });
  elements.workerNameInput.addEventListener("change", updateWorkerRunHint);
  elements.workerRunForm.addEventListener("submit", runAgentWorker);
  elements.applyAuditList.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-rollback-audit-id]");
    if (!button) return;
    await rollbackApplyAudit(Number(button.dataset.rollbackAuditId));
  });

  bindHelpTooltips();
  updateWorkerRunHint();
}

function updateWorkerRunHint() {
  const workerName = elements.workerNameInput.value;
  const hints = {
    low_risk_apply_batch: "Low-risk apply runs in dry-run only. Real apply stays disabled from the console.",
    enrichment_draft_batch: "Enrichment fills pending drafts; it may call the LLM but does not create final ingredients.",
    ingredient_creation_batch: "Ingredient creation only consumes ready enrichment drafts and is gated by backend flags."
  };

  elements.workerRunHint.textContent = hints[workerName] ?? "Worker execution is bounded by backend policy and audit logs.";
}

function bindHelpTooltips() {
  tooltip.node = document.createElement("div");
  tooltip.node.className = "help-popover";
  tooltip.node.setAttribute("role", "tooltip");
  tooltip.node.hidden = true;
  document.body.append(tooltip.node);

  document.addEventListener("pointerover", (event) => {
    const target = event.target.closest("[data-help]");
    if (!target) return;
    showHelpTooltip(target);
  });

  document.addEventListener("pointerout", (event) => {
    const target = event.target.closest("[data-help]");
    if (!target) return;
    hideHelpTooltip();
  });

  document.addEventListener("focusin", (event) => {
    const target = event.target.closest("[data-help]");
    if (!target) return;
    showHelpTooltip(target);
  });

  document.addEventListener("focusout", (event) => {
    const target = event.target.closest("[data-help]");
    if (!target) return;
    hideHelpTooltip();
  });

  window.addEventListener("scroll", () => {
    if (tooltip.activeTarget) positionHelpTooltip(tooltip.activeTarget);
  }, true);

  window.addEventListener("resize", () => {
    if (tooltip.activeTarget) positionHelpTooltip(tooltip.activeTarget);
  });
}

function showHelpTooltip(target) {
  const text = target.dataset.help;
  if (!text || !tooltip.node) return;

  tooltip.activeTarget = target;
  tooltip.node.textContent = text;
  tooltip.node.hidden = false;
  positionHelpTooltip(target);
}

function hideHelpTooltip() {
  if (!tooltip.node) return;
  tooltip.activeTarget = null;
  tooltip.node.hidden = true;
}

function positionHelpTooltip(target) {
  if (!tooltip.node) return;

  const rect = target.getBoundingClientRect();
  const margin = 10;
  const tooltipRect = tooltip.node.getBoundingClientRect();
  const width = tooltipRect.width || 280;
  const height = tooltipRect.height || 44;
  const centeredLeft = rect.left + rect.width / 2 - width / 2;
  const left = Math.min(Math.max(centeredLeft, margin), window.innerWidth - width - margin);
  const topCandidate = rect.top - height - 10;
  const top = topCandidate > margin ? topCandidate : rect.bottom + 10;

  tooltip.node.style.left = `${Math.round(left)}px`;
  tooltip.node.style.top = `${Math.round(top)}px`;
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

  if (workerName === "ingredient_creation_batch") {
    return {
      worker_name: "ingredient_creation_batch",
      action: "create_ingredient",
      limit,
      source_domain: sourceDomain,
      risk_ceiling: "low",
      dry_run: false,
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
  const details = result.details ?? {};
  const topSummary = details.summary ?? {};
  const workerSummary = topSummary.worker_summary ?? details.worker_result?.summary ?? {};
  const runId = details.run_id ?? details.worker_result?.agent_run_id ?? "none";
  const jobId = details.worker_job_id ?? details.worker_result?.agent_worker_job_id ?? "none";
  const workerName = topSummary.worker_name ?? details.worker_result?.worker ?? "worker";
  const mode = workerSummary.mode ?? (details.worker_result?.dry_run ? "dry_run" : "run");
  const total = Number(workerSummary.total ?? 0);
  const failed = Number(workerSummary.failed ?? 0);
  const applied = Number(workerSummary.applied ?? workerSummary.created ?? 0);
  const appliedLabel = workerName === "run-catalog-ingredient-creation-batch" ||
      workerName === "ingredient_creation_batch"
    ? "Created"
    : "Applied";
  const durationMs = Number(topSummary.duration_ms ?? workerSummary.duration_ms ?? 0);

  elements.workerRunResult.hidden = false;
  elements.workerRunResult.innerHTML = `
    <article class="worker-job run-result-card ${result.ok ? "" : "audit-record"}">
      <header>
        <div>
          <strong>${escapeHTML(result.message)}</strong>
          <span>${escapeHTML(workerName)} · ${escapeHTML(mode)}</span>
        </div>
        <div class="badge-line">
          ${badge(result.status)}
        </div>
      </header>
      <div class="run-metrics">
        ${metricCell("Run", `#${runId}`, "ID della run dell'agente manager. Raggruppa la richiesta e tutti gli eventi collegati.")}
        ${metricCell("Job", `#${jobId}`, "ID del lavoro Autopilot delegato dall'agente. Utile per audit e debug.")}
        ${metricCell("Eligible", total, "Quanti elementi erano pronti per questo worker secondo i controlli backend.")}
        ${metricCell(appliedLabel, applied, "Quanti elementi sono stati modificati dal worker. Per la creazione ingredienti indica i nuovi canonici creati da draft pronte.")}
        ${metricCell("Failed", failed, "Quanti elementi hanno fallito durante il worker. Se sale, va controllato prima di proseguire.")}
        ${metricCell("Duration", formatDuration(durationMs), "Quanto tempo ha impiegato la run. Aiuta a capire se un worker sta rallentando.")}
      </div>
      ${result.details ? detailsBlock("Raw worker response", result.details) : ""}
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
    state.draftsByText = new Map();
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
  const items = latestOpenItems(data);
  state.draftsByText = await fetchDraftsForItems(items);
  state.selected = items.find((item) => Number(item.proposal_id) === previousSelectionId) ?? items[0] ?? null;
  if (!state.selected || Number(state.selected.proposal_id) !== previousSelectionId) {
    state.learningMemory = null;
  }
  renderInbox();
  const loadedItems = Array.isArray(data?.items) ? data.items.length : 0;
  const hiddenDuplicates = Math.max(loadedItems - items.length, 0);
  setStatus(
    hiddenDuplicates > 0 && elements.latestOnlyInput?.checked
      ? `Loaded ${items.length} proposals, hiding ${hiddenDuplicates} historical duplicates.`
      : `Loaded ${loadedItems} proposals.`
  );
  await loadOperations({ silent: true });
}

async function loadOperations(options = {}) {
  if (!state.session) return;
  if (!options.silent) {
    setStatus("Loading agent operations...");
  }

  const todayISO = new Intl.DateTimeFormat("en-CA").format(new Date());

  const [
    summaryResult,
    autoApplySummaryResult,
    diagnosticsResult,
    scheduleStatusResult,
    scheduleGuardResult,
    latestDigestResult,
    scheduleShiftHealthResult,
    scheduleShiftRunsResult,
    jobsResult,
    applyAuditsResult
  ] = await Promise.all([
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
      .from("catalog_agent_dev_schedule_status")
      .select("*")
      .eq("environment", "dev")
      .maybeSingle(),
    state.client.rpc("catalog_agent_dev_schedule_guard", {
      p_environment: "dev"
    }),
    state.client
      .from("catalog_agent_daily_digests")
      .select("id,environment,report_date,status,anomaly_count,anomalies,recommended_next_action,updated_at")
      .eq("environment", "dev")
      .order("report_date", { ascending: false })
      .limit(1)
      .maybeSingle(),
    state.client
      .from("catalog_agent_dev_shift_health")
      .select("*")
      .maybeSingle(),
    state.client
      .from("catalog_agent_dev_shift_runs")
      .select("id,status,skip_reason,error_message,duration_ms,started_at,finished_at,guard_snapshot,worker_results,skipped_workers")
      .eq("environment", "dev")
      .order("started_at", { ascending: false })
      .limit(8),
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
  if (scheduleStatusResult.error) {
    setStatus(scheduleStatusResult.error.message, "error");
    return;
  }
  if (scheduleGuardResult.error) {
    setStatus(scheduleGuardResult.error.message, "error");
    return;
  }
  if (latestDigestResult.error) {
    setStatus(latestDigestResult.error.message, "error");
    return;
  }
  if (scheduleShiftHealthResult.error) {
    setStatus(scheduleShiftHealthResult.error.message, "error");
    return;
  }
  if (scheduleShiftRunsResult.error) {
    setStatus(scheduleShiftRunsResult.error.message, "error");
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
    scheduleStatus: scheduleStatusResult.data ?? null,
    scheduleGuard: scheduleGuardResult.data ?? null,
    latestDigest: latestDigestResult.data ?? null,
    scheduleShiftHealth: scheduleShiftHealthResult.data ?? null,
    scheduleShiftRuns: Array.isArray(scheduleShiftRunsResult.data) ? scheduleShiftRunsResult.data : [],
    workerJobs: Array.isArray(jobsResult.data) ? jobsResult.data : [],
    applyAudits: Array.isArray(applyAuditsResult.data) ? applyAuditsResult.data : []
  };
  renderOperations();
  if (!options.silent) {
    setStatus("Agent operations loaded.", "success");
  }
}

async function fetchDraftsForItems(items) {
  const normalizedTexts = [...new Set(items
    .map((item) => normalizeKey(item.proposal?.normalized_text))
    .filter(Boolean))];

  if (normalizedTexts.length === 0) {
    return new Map();
  }

  const { data, error } = await state.client
    .from("catalog_ingredient_enrichment_drafts")
    .select("normalized_text,status,ingredient_type,canonical_name_it,canonical_name_en,suggested_slug,confidence_score,validated_ready,validated_errors,updated_at")
    .in("normalized_text", normalizedTexts);

  if (error) {
    setStatus(`Draft status unavailable: ${error.message}`, "error");
    return new Map();
  }

  return new Map((Array.isArray(data) ? data : [])
    .map((draft) => [normalizeKey(draft.normalized_text), draft]));
}

function renderOperations() {
  const summary = state.operations.summary ?? {};
  const autoApplySummary = state.operations.autoApplySummary ?? {};
  const diagnostics = state.operations.autoApplyDiagnostics ?? {};
  const scheduleStatus = state.operations.scheduleStatus ?? {};
  const scheduleGuard = state.operations.scheduleGuard ?? {};
  const latestDigest = state.operations.latestDigest ?? {};
  const scheduleShiftHealth = state.operations.scheduleShiftHealth ?? {};
  const scheduleShiftRuns = state.operations.scheduleShiftRuns ?? [];
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
  renderScheduleStatus(scheduleStatus, scheduleGuard, latestDigest, scheduleShiftHealth);
  renderShiftRunHistory(scheduleShiftRuns);
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

function renderScheduleStatus(scheduleStatus, scheduleGuard, latestDigest, scheduleShiftHealth) {
  const guardOk = scheduleGuard?.ok === true;
  const guardReason = scheduleGuard?.reason ?? (guardOk ? "allowed" : "not loaded");
  const digestStatus = latestDigest?.status ?? scheduleStatus?.latest_digest_status ?? "none";
  const anomalyCount = Number(latestDigest?.anomaly_count ?? scheduleStatus?.latest_anomaly_count ?? 0);
  const reportDate = latestDigest?.report_date ?? scheduleStatus?.latest_report_date ?? null;
  const anomalies = Array.isArray(latestDigest?.anomalies) ? latestDigest.anomalies : [];
  const shiftHealthStatus = scheduleShiftHealth?.shift_health_status ?? "idle";
  const shiftRunsToday = Number(scheduleShiftHealth?.total_shift_runs_today ?? 0);
  const windowStatus = scheduleStatus?.window_status ?? "unknown";

  elements.scheduleGuardState.textContent = guardOk ? "Allowed" : humanizeToken(guardReason);
  elements.scheduleKillSwitch.textContent = scheduleGuard?.kill_switch === true || scheduleStatus?.enabled === false ? "On" : "Off";
  elements.scheduleAnomalyCount.textContent = String(anomalyCount);
  elements.scheduleLatestDigest.textContent = reportDate ? `${reportDate}` : "None";
  elements.scheduleShiftHealth.textContent = humanizeToken(shiftHealthStatus);
  elements.scheduleShiftRunsToday.textContent = String(shiftRunsToday);
  elements.scheduleWindowStatus.textContent = humanizeToken(windowStatus);
  elements.scheduleDigestStatus.textContent = humanizeToken(digestStatus);
  elements.scheduleDigestStatus.dataset.status = digestStatus;
  elements.scheduleNextAction.textContent = latestDigest?.recommended_next_action
    ?? scheduleStatus?.latest_recommended_next_action
    ?? "No scheduled autonomy digest has been stored yet.";
  elements.scheduleWindowMessage.textContent = schedulerWindowMessage(scheduleStatus, scheduleGuard);
  elements.scheduleShiftMessage.textContent = scheduleShiftHealth?.shift_health_message
    ?? "No dev-shift health record loaded yet.";

  if (anomalies.length === 0) {
    elements.scheduleAnomalyList.innerHTML = renderShiftHealthDetails(scheduleShiftHealth) +
      "<p>No anomalies in the latest digest.</p>";
    return;
  }

  elements.scheduleAnomalyList.innerHTML = renderShiftHealthDetails(scheduleShiftHealth) + anomalies.map((anomaly) => `
    <article>
      <strong>${escapeHTML(humanizeToken(anomaly.code ?? "anomaly"))}</strong>
      <span>${escapeHTML(anomaly.severity ?? "unknown")}</span>
      <p>${escapeHTML(anomaly.message ?? "No anomaly message.")}</p>
      ${Number.isFinite(Number(anomaly.count)) ? `<small>Count: ${escapeHTML(anomaly.count)}</small>` : ""}
    </article>
  `).join("");
}

function schedulerWindowMessage(scheduleStatus, scheduleGuard) {
  const status = scheduleStatus?.window_status ?? "unknown";
  const label = scheduleStatus?.window_label ? ` (${scheduleStatus.window_label})` : "";
  const until = scheduleStatus?.enabled_until ? formatDate(scheduleStatus.enabled_until) : null;

  if (status === "disabled") {
    return "Scheduler window is closed. Cron may tick, but the guard will skip.";
  }
  if (status === "missing_expiry") {
    return "Scheduler is enabled without an expiry. Guard blocks this as unsafe.";
  }
  if (status === "expired") {
    return `Scheduler window expired${until ? ` at ${until}` : ""}. Guard blocks future work.`;
  }
  if (status === "open") {
    return `Scheduler window is open until ${until ?? "unknown time"}${label}.`;
  }

  const reason = scheduleGuard?.reason ? humanizeToken(scheduleGuard.reason) : "not loaded";
  return `Scheduler window state unavailable; guard says ${reason}.`;
}

function renderShiftHealthDetails(scheduleShiftHealth) {
  if (!scheduleShiftHealth || Object.keys(scheduleShiftHealth).length === 0) {
    return "";
  }

  return `
    <article class="shift-health-card ${escapeHTML(scheduleShiftHealth.shift_health_status ?? "idle")}">
      <strong>Dev-shift lane: ${escapeHTML(humanizeToken(scheduleShiftHealth.shift_health_status ?? "idle"))}</strong>
      <span>Latest shift #${escapeHTML(scheduleShiftHealth.latest_shift_run_id ?? "none")}</span>
      <p>${escapeHTML(scheduleShiftHealth.shift_health_message ?? "No shift health message.")}</p>
      <small>
        Today: ${escapeHTML(scheduleShiftHealth.completed_shift_runs_today ?? 0)} completed,
        ${escapeHTML(scheduleShiftHealth.skipped_shift_runs_today ?? 0)} skipped,
        ${escapeHTML(scheduleShiftHealth.failed_shift_runs_today ?? 0)} failed
      </small>
    </article>
  `;
}

function renderShiftRunHistory(shiftRuns) {
  if (!Array.isArray(shiftRuns) || shiftRuns.length === 0) {
    elements.scheduleShiftRunsList.innerHTML = "<p>No dev-shift runs yet. The scheduler lane is still waiting for its first attempt.</p>";
    return;
  }

  elements.scheduleShiftRunsList.innerHTML = `
    <header class="shift-run-list-header">
      <strong>Recent dev shifts</strong>
      <span>Latest ${escapeHTML(shiftRuns.length)} attempts</span>
    </header>
    ${shiftRuns.map(renderShiftRunCard).join("")}
  `;
}

function renderShiftRunCard(shiftRun) {
  const workerResults = Array.isArray(shiftRun.worker_results) ? shiftRun.worker_results : [];
  const skippedWorkers = Array.isArray(shiftRun.skipped_workers) ? shiftRun.skipped_workers : [];
  const guard = shiftRun.guard_snapshot && typeof shiftRun.guard_snapshot === "object"
    ? shiftRun.guard_snapshot
    : {};
  const guardReason = guard.reason ?? (guard.ok === true ? "allowed" : "unknown");
  const workerSummary = workerResults.length > 0
    ? `${workerResults.length} worker result${workerResults.length === 1 ? "" : "s"}`
    : "no workers";
  const skippedSummary = skippedWorkers.length > 0
    ? `${skippedWorkers.length} skipped`
    : "none skipped";
  const reason = shiftRun.error_message
    ?? shiftRun.skip_reason
    ?? `Guard ${humanizeToken(guardReason)}`;

  return `
    <article class="shift-run-card ${escapeHTML(shiftRun.status ?? "unknown")}">
      <div class="shift-run-main">
        <div>
          <strong>Shift #${escapeHTML(shiftRun.id)}</strong>
          <span>${escapeHTML(formatDate(shiftRun.started_at))}</span>
        </div>
        <div class="badge-line">
          ${badge(shiftRun.status)}
          ${badge(guard.ok === true ? "guard_allowed" : "guard_blocked")}
        </div>
      </div>
      <p>${escapeHTML(reason)}</p>
      <div class="worker-job-meta">
        <span>Duration ${escapeHTML(formatDuration(shiftRun.duration_ms))}</span>
        <span>${escapeHTML(workerSummary)}</span>
        <span>${escapeHTML(skippedSummary)}</span>
      </div>
      ${workerResults.length > 0 ? renderShiftWorkers(workerResults) : ""}
    </article>
  `;
}

function renderShiftWorkers(workerResults) {
  return `
    <div class="shift-workers">
      ${workerResults.map((result) => `
        <span>
          ${escapeHTML(result.worker_name ?? result.worker ?? "worker")}
          ${result.dry_run === true ? "(dry-run)" : ""}
        </span>
      `).join("")}
    </div>
  `;
}

function renderAutoApplyDiagnostics(diagnostics) {
  if (!diagnostics?.ok) {
    elements.autoApplyDiagnostics.innerHTML = "<p>Auto-apply diagnostics are not loaded yet.</p>";
    return;
  }

  const counts = diagnostics.counts ?? {};
  const readyCount = Number(diagnostics.ready_for_low_risk_apply ?? 0);
  const readyPreview = Array.isArray(diagnostics.ready_preview) ? diagnostics.ready_preview : [];

  const terminalCount = Number(counts.auto_applied ?? 0) + Number(counts.superseded ?? 0) + Number(counts.rejected ?? 0);
  const readinessTone = readyCount > 0 ? "ready" : "idle";

  elements.autoApplyDiagnostics.innerHTML = `
    <article class="worker-job readiness-card ${readinessTone}">
      <header>
        <div>
          <strong>Low-risk apply readiness</strong>
          <span>${escapeHTML(diagnostics.explanation ?? "No explanation available.")}</span>
        </div>
        <div class="badge-line">
          ${badge(`${readyCount}_ready`)}
        </div>
      </header>
      <div class="readiness-main">
        <div>
          <strong>${escapeHTML(readyCount)}</strong>
          <span>ready now</span>
        </div>
        <p>${escapeHTML(diagnostics.explanation ?? "No explanation available.")}</p>
      </div>
      <div class="pipeline-flow" aria-label="Low-risk apply pipeline">
        ${pipelineNode("Draft", counts.draft, "neutral", "Proposte create dall'agente ma non ancora mandate ai controlli deterministici.")}
        ${pipelineNode("Queued", counts.queued_for_validation, "neutral", "Proposte in coda per il validatore backend.")}
        ${pipelineNode("Review", counts.needs_human_review, "neutral", "Casi dove l'agente chiede aiuto umano o più evidenza.")}
        ${pipelineNode("Failed", counts.failed_validation, "warning", "Proposte bloccate dal validatore perché non sicure o non complete.")}
        ${pipelineNode("Validated", counts.validated_total, "neutral", "Proposte che hanno passato i controlli, ma non sono necessariamente applicabili automaticamente.")}
        ${pipelineNode("Ready", readyCount, readyCount > 0 ? "ok" : "neutral", "Proposte low-risk pronte per dry-run o futuro apply controllato.")}
        ${pipelineNode("Handled", terminalCount, "ok", "Proposte già chiuse: applicate, superate o scartate.")}
      </div>
      <div class="diagnostic-grid">
        ${diagnosticCell("Ready", readyCount, "Candidati che soddisfano tutti i criteri low-risk auto-apply.")}
        ${diagnosticCell("Draft", counts.draft, "Proposte ancora grezze, da validare.")}
        ${diagnosticCell("Queued", counts.queued_for_validation, "Proposte già pronte per essere validate.")}
        ${diagnosticCell("Needs review", counts.needs_human_review, "Casi dove serve giudizio umano o altra evidenza.")}
        ${diagnosticCell("Failed validation", counts.failed_validation, "Proposte che il backend ha rifiutato per sicurezza o conflitti.")}
        ${diagnosticCell("Validated total", counts.validated_total, "Tutte le proposte validate, anche quelle non applicabili in automatico.")}
        ${diagnosticCell("Not eligible", counts.validated_not_auto_apply_eligible, "Validate ma non marcate come auto-applicabili. Di solito richiedono review o policy.")}
        ${diagnosticCell("Auto-applied", counts.auto_applied, "Proposte già applicate automaticamente e tracciate in audit.")}
      </div>
      ${readyPreview.length > 0 ? detailsBlock("Ready preview", { ready_preview: readyPreview }) : ""}
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
  const rawItems = Array.isArray(state.inbox?.items) ? state.inbox.items : [];
  const items = latestOpenItems(state.inbox);
  const byStatus = countItemsByStatus(items);
  const hiddenDuplicates = Math.max(rawItems.length - items.length, 0);

  elements.totalCount.textContent = String(items.length);
  elements.needsReviewCount.textContent = String(byStatus.needs_human_review ?? 0);
  elements.validatedCount.textContent = String(byStatus.validated ?? 0);
  elements.failedCount.textContent = String(byStatus.failed_validation ?? 0);

  if (state.selected && !items.some((item) => Number(item.proposal_id) === Number(state.selected?.proposal_id))) {
    state.selected = items[0] ?? null;
    state.learningMemory = null;
  }

  elements.proposalList.replaceChildren(...items.map(renderProposalRow));
  if (hiddenDuplicates > 0 && elements.latestOnlyInput?.checked) {
    const note = document.createElement("div");
    note.className = "proposal-list-note";
    note.textContent = `${hiddenDuplicates} historical duplicates hidden. Disable "Latest per term" to inspect them.`;
    elements.proposalList.prepend(note);
  }
  renderSelectedProposal();
}

function latestOpenItems(inbox) {
  const items = Array.isArray(inbox?.items) ? inbox.items : [];
  if (!elements.latestOnlyInput?.checked) {
    return items;
  }

  const bestByText = new Map();
  for (const item of items) {
    const key = normalizeKey(item?.proposal?.normalized_text);
    if (!key) continue;
    const current = bestByText.get(key);
    if (!current || proposalSortScore(item) < proposalSortScore(current)) {
      bestByText.set(key, item);
    }
  }

  return Array.from(bestByText.values()).sort((left, right) => {
    const leftScore = proposalSortScore(left);
    const rightScore = proposalSortScore(right);
    if (leftScore !== rightScore) return leftScore - rightScore;
    return Number(right.proposal_id ?? 0) - Number(left.proposal_id ?? 0);
  });
}

function proposalSortScore(item) {
  const proposal = item?.proposal ?? {};
  const statusRank = {
    draft: 0,
    queued_for_validation: 1,
    validated: 2,
    needs_human_review: 3,
    failed_validation: 4
  }[proposal.status] ?? 9;
  const riskRank = {
    critical: 0,
    high: 1,
    unknown: 2,
    medium: 3,
    low: 4
  }[proposal.risk_level] ?? 9;
  const typeRank = {
    approve_alias: 0,
    create_canonical: 1,
    add_localization: 2,
    needs_human_review: 3
  }[proposal.proposal_type] ?? 9;
  const createdAt = Date.parse(proposal.created_at ?? "") || 0;
  return statusRank * 1_000_000_000_000 + riskRank * 10_000_000_000 + typeRank * 100_000_000 - createdAt / 1000;
}

function countItemsByStatus(items) {
  return items.reduce((counts, item) => {
    const status = item?.proposal?.status ?? "unknown";
    counts[status] = (counts[status] ?? 0) + 1;
    return counts;
  }, {});
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
  const draft = state.draftsByText.get(normalizeKey(proposal.normalized_text)) ?? null;
  const actionState = getProposalActionState(proposal, draft);

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

      ${canonicalDraftPanel(proposal, proposed, draft)}

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
            ${actionButton("prepareDraft", "Prepare draft", actionState.prepareDraft)}
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
  bindEnabledAction("prepareDraft", prepareCanonicalDraft);
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

async function prepareCanonicalDraft() {
  const proposalId = state.selected?.proposal_id;
  if (!proposalId) return;

  const note = elements.proposalDetail.querySelector("#reviewNote")?.value?.trim() ?? "";
  setStatus("Preparing canonical enrichment draft...");
  const { data, error } = await state.client.rpc("prepare_catalog_agent_canonical_enrichment_draft", {
    p_proposal_id: proposalId,
    p_reviewer_note: note || null
  });

  if (error) {
    setStatus(error.message, "error");
    return;
  }

  await loadInbox({ keepProposalId: proposalId });
  await loadOperations({ silent: true });
  const draftStatus = data?.draft_status ?? "pending";
  setStatus(`Canonical draft prepared (${draftStatus}). Run the enrichment worker when ready.`, "success");
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
      ${learningMemoryCards(data)}
      <details class="details-block">
        <summary>Raw learning payload</summary>
        ${jsonBlock(data)}
      </details>
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

function canonicalDraftPanel(proposal, proposed, draft) {
  if (proposal.proposal_type !== "create_canonical") {
    return "";
  }

  const draftStatus = draft?.status ?? "not_prepared";
  const draftSlug = draft?.suggested_slug ?? proposed.proposed_slug ?? "none";
  const draftName = draft?.canonical_name_it ?? draft?.canonical_name_en ?? proposed.proposed_localized_name ?? "none";
  const validationState = draft?.validated_ready === true ? "ready" : "not_ready";

  return `
    <section class="detail-section canonical-path">
      <h3>Canonical creation path</h3>
      <p>This proposal creates a catalog gap workflow. It prepares an enrichment draft first; ingredient creation stays behind worker validation.</p>
      <div class="canonical-steps">
        ${pathStep("Proposal", proposal.status, "The agent identified a missing canonical ingredient.")}
        ${pathStep("Draft", draftStatus, "An enrichment draft gives Autopilot a bounded work item to enrich.")}
        ${pathStep("Validation", validationState, "Draft validators must pass before any ingredient can be created.")}
        ${pathStep("Creation", "gated", "Canonical creation is still admin/worker controlled, never direct from this panel.")}
      </div>
      <div class="detail-grid">
        ${detailCell("Draft slug", draftSlug)}
        ${detailCell("Draft name", draftName)}
        ${detailCell("Draft type", draft?.ingredient_type ?? "unknown")}
        ${detailCell("Draft updated", draft?.updated_at ? formatDate(draft.updated_at) : "none")}
      </div>
      ${draft?.validated_errors ? detailsBlock("Draft validation errors", draft.validated_errors) : ""}
    </section>
  `;
}

function pathStep(label, value, helpText = "") {
  return `
    <div>
      <span>${escapeHTML(label)} ${helpTip(helpText)}</span>
      <strong>${escapeHTML(value ?? "none")}</strong>
    </div>
  `;
}

function metricCell(label, value, helpText = "") {
  return `
    <div>
      <span>${escapeHTML(label)} ${helpTip(helpText)}</span>
      <strong>${escapeHTML(value ?? 0)}</strong>
    </div>
  `;
}

function diagnosticCell(label, value, helpText = "") {
  return `
    <div>
      <span>${escapeHTML(label)} ${helpTip(helpText)}</span>
      <strong>${escapeHTML(value ?? 0)}</strong>
    </div>
  `;
}

function pipelineNode(label, value, tone = "neutral", helpText = "") {
  return `
    <div class="pipeline-node ${escapeHTML(tone)}">
      <span>${escapeHTML(label)} ${helpTip(helpText)}</span>
      <strong>${escapeHTML(value ?? 0)}</strong>
    </div>
  `;
}

function getProposalActionState(proposal, draft = null) {
  const status = String(proposal.status ?? "");
  const proposalType = String(proposal.proposal_type ?? "");
  const riskLevel = String(proposal.risk_level ?? "");
  const actionableTypes = ["approve_alias", "add_localization", "create_canonical"];
  const applyTypes = ["approve_alias", "add_localization"];
  const isClosed = ["applied", "rejected", "superseded"].includes(status);
  const draftStatus = String(draft?.status ?? "");
  const canPrepareDraft = !isClosed
    && proposalType === "create_canonical"
    && draftStatus !== "ready";
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
      canApply,
      canPrepareDraft,
      draftStatus
    }),
    prepareDraft: {
      enabled: canPrepareDraft,
      reason: canPrepareDraft ? "" : "Only open create_canonical proposals without a ready draft can prepare an enrichment draft."
    },
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
  if (input.proposalType === "create_canonical") {
    if (input.draftStatus === "ready") {
      return "A ready enrichment draft exists. Validate the proposal and use the governed creation flow, not direct apply.";
    }
    if (input.canPrepareDraft) {
      return "This is a catalog-gap proposal. Prepare an enrichment draft, then run the enrichment worker before creation.";
    }
    return "This catalog-gap proposal is not ready for draft preparation.";
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

function detailsBlock(label, value) {
  return `
    <details class="details-block">
      <summary>${escapeHTML(label)}</summary>
      ${jsonBlock(value)}
    </details>
  `;
}

function helpTip(text) {
  if (!text) return "";
  return `<span class="help-tip" tabindex="0" aria-label="${escapeHTML(text)}" data-help="${escapeHTML(text)}">?</span>`;
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

function learningMemoryCards(value) {
  const termLearnings = value?.term_learnings ?? {};
  const cards = Object.entries(termLearnings)
    .flatMap(([term, items]) => Array.isArray(items)
      ? items.map((item) => learningMemoryCard(term, item))
      : [])
    .join("");

  if (!cards) {
    return `<p>No learning memory for this term yet.</p>`;
  }

  return `<div class="learning-card-list">${cards}</div>`;
}

function learningMemoryCard(term, item) {
  const type = item.learning_type ?? "learning";
  const status = item.status ?? "unknown";
  const severity = item.severity ?? "medium";
  const problem = item.observed_problem ?? "No observed problem recorded.";
  const decision = item.corrected_decision ?? "No corrected decision recorded yet.";
  const policy = item.policy_implication ?? "No policy implication recorded yet.";
  return `
    <article class="learning-card">
      <header>
        <strong>${escapeHTML(term)}</strong>
        <span>${escapeHTML(type)} · ${escapeHTML(status)} · ${escapeHTML(severity)}</span>
      </header>
      <dl>
        <div>
          <dt>Observed</dt>
          <dd>${escapeHTML(problem)}</dd>
        </div>
        <div>
          <dt>Correct decision</dt>
          <dd>${escapeHTML(decision)}</dd>
        </div>
        <div>
          <dt>Policy</dt>
          <dd>${escapeHTML(policy)}</dd>
        </div>
      </dl>
    </article>
  `;
}

function parseCSV(value) {
  return String(value ?? "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
}

function normalizeKey(value) {
  return String(value ?? "").trim().toLowerCase();
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

function formatDuration(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return "0 ms";
  if (parsed < 1000) return `${Math.round(parsed)} ms`;
  return `${(parsed / 1000).toFixed(1)} s`;
}

function humanizeToken(value) {
  return String(value ?? "")
    .replaceAll("_", " ")
    .trim()
    .replace(/^\w/, (letter) => letter.toUpperCase()) || "Unknown";
}

function escapeHTML(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}
