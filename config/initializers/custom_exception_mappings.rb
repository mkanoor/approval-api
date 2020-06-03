# Define custom exception mappings here to make sure they are loaded last
ActionDispatch::ExceptionWrapper.rescue_responses.merge!(
  "ActiveRecord::RecordNotSaved"               => :bad_request,
  "ActiveRecord::RecordInvalid"                => :bad_request,
  "ActiveRecord::RecordNotUnique"              => :bad_request,
  "ActionController::ParameterMissing"         => :bad_request,
  "Exceptions::InvalidStateTransitionError"    => :bad_request,
  "Exceptions::NegativeSequenceError"          => :bad_request,
  "Exceptions::UserError"                      => :bad_request,
  "Exceptions::KieError"                       => :bad_request,
  "Exceptions::InvalidURLError"                => :bad_request,
  "Exceptions::TaggingError"                   => :bad_request,
  "Exceptions::NotAuthorizedError"             => :forbidden,
  "Pundit::NotAuthorizedError"                 => :forbidden,
  "Exceptions::RBACError"                      => :service_unavailable,
  "Exceptions::NetworkError"                   => :service_unavailable,
  "Exceptions::TimedOutError"                  => :service_unavailable,
  "Insights::API::Common::RBAC::NetworkError"  => :service_unavailable,
  "Insights::API::Common::RBAC::TimedOutError" => :service_unavailable
)
