module Api
  module V1x0
    class RequestsController < ApplicationController
      include Mixins::IndexMixin
      include Mixins::RBACMixin

      before_action :read_access_check, :only => %i[show]
      before_action :create_access_check, :only => %i[create]

      def create
        req = RequestCreateService.new(params.require(:workflow_id)).create(request_params)
        json_response(req, :created)
      end

      def show
        req = Request.find(params.require(:id))
        json_response(req)
      end

      def index
        reqs = if params[:workflow_id]
                 Request.includes(:stages).where(:workflow_id => params.require(:workflow_id))
               elsif params[:approver]
                 RequestListByApproverService.new(params.require(:approver)).list
               else
                 Request.includes(:stages)
               end

        RBAC::Access.enabled? ? collection(rbac_scope(reqs)) : collection(reqs)
      end

      private

      def request_params
        params.permit(:name, :description, :requester_name, :content => {})
      end

      def rbac_scope(relation)
        raise Exceptions::NotAuthorizedError, "Current role cannot access #{request.path}" unless right_path?

        ids = if approver_endpoint?
                { :id => RBAC::Access.approver_id_list(relation.model.table_name) }
              elsif requester_endpoint?
                { :id => RBAC::Access.owner_id_list(relation.model.table_name) }
              end

        Rails.logger.info("Accessible request ids: #{ids}")

        relation.where(ids)
      end

      def right_path?
        (RBAC::Access.approver? && approver_endpoint?) || (RBAC::Access.admin? && admin_endpoint?) || (requester_endpoint? && !RBAC::Access.admin? && !RBAC::Access.approver?)
      end

      def admin_endpoint?
        request.path.end_with?("/admin/requests") || (request.path.end_with?("/requests") && !requester_endpoint? && !approver_endpoint?)
      end

      def requester_endpoint?
        request.path.end_with?("/requester/requests")
      end

      def approver_endpoint?
        request.path.end_with?("/approver/requests")
      end
    end
  end
end
