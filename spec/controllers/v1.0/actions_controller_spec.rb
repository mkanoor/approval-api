RSpec.describe Api::V1x0::ActionsController, :type => :request do
  include_context "rbac_objects"
  let(:tenant) { create(:tenant, :external_tenant => 369_233) }

  let!(:template) { create(:template) }
  let!(:workflow) { create(:workflow, :template_id => template.id) }
  let!(:request) { create(:request, :with_context, :workflow_id => workflow.id, :tenant_id => tenant.id) }
  let!(:group_ref) { "990" }
  let!(:stage) { create(:stage, :group_ref => group_ref, :request => request, :tenant_id => tenant.id) }
  let(:stage_id) { stage.id }

  let!(:actions) { create_list(:action, 10, :stage_id => stage.id, :tenant_id => tenant.id) }
  let(:id) { actions.first.id }

  let(:filter) { instance_double(RBACApiClient::ResourceDefinitionFilter, :key => 'id', :operation => 'equal', :value => workflow.id) }
  let(:resource_def) { instance_double(RBACApiClient::ResourceDefinition, :attribute_filter => filter) }
  let(:access) { instance_double(RBACApiClient::Access, :permission => "approval:workflows:approve", :resource_definitions => [resource_def]) }
  let(:full_approver_acls) { approver_acls << access }

  let(:api_version) { version }

  before do
    allow(rs_class).to receive(:call).with(RBACApiClient::AccessApi).and_yield(api_instance)
  end

  # Test suite for GET /actions/:id
  describe 'GET /actions/:id' do
    context 'admin role when the record exists' do
      before do
        allow(RBAC::Access).to receive(:admin?).and_return(true)
        with_modified_env :APP_NAME => app_name do
          get "#{api_version}/actions/#{id}", :headers => default_headers
        end
      end

      it 'returns the action' do
        action = actions.first

        expect(json).not_to be_empty
        expect(json['id']).to eq(action.id.to_s)
        expect(json['created_at']).to eq(action.created_at.iso8601)
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'admin role when the record does not exist' do
      let!(:id) { 0 }
      before do
        allow(RBAC::Access).to receive(:admin?).and_return(true)
        with_modified_env :APP_NAME => app_name do
          get "#{api_version}/actions/#{id}", :headers => default_headers
        end
      end

      it 'returns status code 404' do
        expect(response).to have_http_status(404)
      end

      it 'returns a not found message' do
        expect(response.body).to match(/Couldn't find Action/)
      end
    end

    context 'approver role can approve' do
      before do
        allow(rs_class).to receive(:paginate).with(api_instance, :get_principal_access, {:scope => 'principal'}, app_name).and_return(full_approver_acls)
        allow(RBAC::Access).to receive(:admin?).and_return(false)
        allow(RBAC::Access).to receive(:approver?).and_return(true)

        with_modified_env :APP_NAME => app_name do
          get "#{api_version}/actions/#{id}", :headers => default_headers
        end
      end

      it 'returns status code 200' do
        expect(response).to have_http_status(200)
      end
    end

    context 'approver role cannot read' do
      before do
        allow(rs_class).to receive(:paginate).with(api_instance, :get_principal_access, {:scope => 'principal'}, app_name).and_return(approver_acls)
        allow(RBAC::Access).to receive(:admin?).and_return(false)
        allow(RBAC::Access).to receive(:approver?).and_return(true)

        with_modified_env :APP_NAME => app_name do
          get "#{api_version}/actions/#{id}", :headers => default_headers
        end
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end

    context 'owner role cannot read' do
      before do
        allow(rs_class).to receive(:paginate).with(api_instance, :get_principal_access, {:scope => 'principal'}, app_name).and_return([])
        allow(RBAC::Access).to receive(:admin?).and_return(false)
        allow(RBAC::Access).to receive(:approver?).and_return(false)
        with_modified_env :APP_NAME => app_name do
          get "#{api_version}/actions/#{id}", :headers => default_headers
        end
      end

      it 'returns status code 403' do
        expect(response).to have_http_status(403)
      end
    end
  end

  describe 'POST /stages/:stage_id/actions' do
    let(:valid_attributes) { { :operation => 'notify', :processed_by => 'abcd' } }
    before do
      allow(Group).to receive(:find)
    end

    context 'admin role when request attributes are valid' do
      it 'returns status code 201' do
        allow(RBAC::Access).to receive(:admin?).and_return(true)
        post "#{api_version}/stages/#{stage_id}/actions", :params => valid_attributes, :headers => default_headers

        expect(response).to have_http_status(201)
      end
    end

    context 'approver role when request attributes are valid' do
      it 'returns status code 201' do
        allow(rs_class).to receive(:paginate).with(api_instance, :get_principal_access, {:scope => 'principal'}, app_name).and_return(approver_acls)
        allow(RBAC::Access).to receive(:admin?).and_return(false)
        allow(RBAC::Access).to receive(:approver?).and_return(true)
        post "#{api_version}/stages/#{stage_id}/actions", :params => valid_attributes, :headers => default_headers

        expect(response).to have_http_status(201)
      end
    end

    context 'owner role when request attributes are valid' do
      it 'returns status code 201' do
        allow(rs_class).to receive(:paginate).with(api_instance, :get_principal_access, {:scope => 'principal'}, app_name).and_return([])
        allow(RBAC::Access).to receive(:admin?).and_return(false)
        allow(RBAC::Access).to receive(:approver?).and_return(false)
        post "#{api_version}/stages/#{stage_id}/actions", :params => valid_attributes, :headers => default_headers

        expect(response).to have_http_status(201)
      end
    end
  end

  describe 'POST /requests/:request_id/actions' do
    let(:req) { create(:request, :with_context, :tenant_id => tenant.id) }

    before do
      allow(Group).to receive(:find)
      allow(rs_class).to receive(:paginate).with(api_instance, :get_principal_access, {:scope => 'principal'}, app_name).and_return([])
      allow(RBAC::Access).to receive(:admin?).and_return(false)
    end

    context 'when request is actionable' do
      let!(:stage1) { create(:stage, :state => Stage::NOTIFIED_STATE, :request => req, :tenant_id => tenant.id) }
      let!(:stage2) { create(:stage, :state => Stage::PENDING_STATE, :request => req, :tenant_id => tenant.id) }
      let(:valid_attributes) { { :operation => 'cancel', :processed_by => 'abcd' } }

      it 'returns status code 201' do
        post "#{api_version}/requests/#{req.id}/actions", :params => valid_attributes, :headers => default_headers

        expect(req.stages.first.state).to eq(Stage::CANCELED_STATE)
        expect(req.stages.last.state).to eq(Stage::SKIPPED_STATE)
        expect(response).to have_http_status(201)
      end
    end

    context 'when request is not actionable' do
      let!(:stage1) { create(:stage, :state => Stage::FINISHED_STATE, :request => req, :tenant_id => tenant.id) }
      let!(:stage2) { create(:stage, :state => Stage::FINISHED_STATE, :request => req, :tenant_id => tenant.id) }
      let(:valid_attributes) { { :operation => 'notify', :processed_by => 'abcd' } }

      it 'returns status code 500' do
        post "#{api_version}/requests/#{req.id}/actions", :params => valid_attributes, :headers => default_headers

        expect(response).to have_http_status(500)
      end
    end
  end
end
