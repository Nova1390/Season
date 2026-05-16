window.SEASON_ADMIN_CONFIG = {
  defaultEnvironment: "dev",
  environments: {
    dev: {
      environmentLabel: "Season-dev",
      supabaseUrl: "https://gyuedxycbnqljryenapx.supabase.co",
      supabaseAnonKey: "paste-dev-anon-key-here",
      capabilities: {
        readOnly: false,
        workerRuns: true,
        proposalReview: true,
        proposalApply: true,
        rollback: true,
        scheduledAutonomy: true
      }
    },
    staging: {
      environmentLabel: "Season-staging",
      supabaseUrl: "https://czdsnnsizyhldiurlmxd.supabase.co",
      supabaseAnonKey: "paste-staging-anon-key-here",
      capabilities: {
        readOnly: true,
        workerRuns: false,
        proposalReview: false,
        proposalApply: false,
        rollback: false,
        scheduledAutonomy: false
      }
    },
    prod: {
      environmentLabel: "Season-prod",
      supabaseUrl: "",
      supabaseAnonKey: "paste-prod-anon-key-here",
      capabilities: {
        readOnly: true,
        workerRuns: false,
        proposalReview: false,
        proposalApply: false,
        rollback: false,
        scheduledAutonomy: false
      }
    }
  },
  defaultStatuses: [
    "draft",
    "failed_validation",
    "queued_for_validation",
    "validated"
  ],
  defaultLimit: 25
};
