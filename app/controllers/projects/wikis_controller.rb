# frozen_string_literal: true

class Projects::WikisController < Projects::ApplicationController
  include PreviewMarkdown
  include Gitlab::Utils::StrongMemoize

  before_action :authorize_read_wiki!
  before_action :authorize_create_wiki!, only: [:edit, :create, :history]
  before_action :authorize_admin_wiki!, only: :destroy
  before_action :load_project_wiki
  before_action :load_page, only: [:show, :edit, :update, :history, :destroy]
  before_action :valid_encoding?, only: [:show, :edit, :update], if: :load_page
  before_action only: [:edit, :update], unless: :valid_encoding? do
    redirect_to(project_wiki_path(@project, @page))
  end

  def pages
    @wiki_pages = Kaminari.paginate_array(@project_wiki.pages).page(params[:page])
    @wiki_entries = WikiPage.group_by_directory(@wiki_pages)
  end

  def show
    view_param = @project_wiki.empty? ? params[:view] : 'create'

    if @page
      set_encoding_error unless valid_encoding?

      render 'show'
    elsif file = @project_wiki.find_file(params[:id], params[:version_id])
      response.headers['Content-Security-Policy'] = "default-src 'none'"
      response.headers['X-Content-Security-Policy'] = "default-src 'none'"

      send_data(
        file.raw_data,
        type: file.mime_type,
        disposition: 'inline',
        filename: file.name
      )
    elsif can?(current_user, :create_wiki, @project) && view_param == 'create'
      @page = build_page(title: params[:id])

      render 'edit'
    else
      render 'empty'
    end
  end

  def edit
  end

  def update
    return render('empty') unless can?(current_user, :create_wiki, @project)

    @page = WikiPages::UpdateService.new(@project, current_user, wiki_params).execute(@page)

    if @page.valid?
      redirect_to(
        project_wiki_path(@project, @page),
        notice: 'Wiki was successfully updated.'
      )
    else
      render 'edit'
    end
  rescue WikiPage::PageChangedError, WikiPage::PageRenameError, Gitlab::Git::Wiki::OperationError => e
    @error = e
    render 'edit'
  end

  def create
    @page = WikiPages::CreateService.new(@project, current_user, wiki_params).execute

    if @page.persisted?
      redirect_to(
        project_wiki_path(@project, @page),
        notice: 'Wiki was successfully updated.'
      )
    else
      render action: "edit"
    end
  rescue Gitlab::Git::Wiki::OperationError => e
    @page = build_page(wiki_params)
    @error = e

    render 'edit'
  end

  def history
    if @page
      @page_versions = Kaminari.paginate_array(@page.versions(page: params[:page].to_i),
                                               total_count: @page.count_versions)
        .page(params[:page])
    else
      redirect_to(
        project_wiki_path(@project, :home),
        notice: "Page not found"
      )
    end
  end

  def destroy
    WikiPages::DestroyService.new(@project, current_user).execute(@page)

    redirect_to project_wiki_path(@project, :home),
                status: 302,
                notice: "Page was successfully deleted"
  rescue Gitlab::Git::Wiki::OperationError => e
    @error = e
    render 'edit'
  end

  def git_access
  end

  private

  def load_project_wiki
    @project_wiki = load_wiki

    # Call #wiki to make sure the Wiki Repo is initialized
    @project_wiki.wiki

    @sidebar_page = @project_wiki.find_sidebar(params[:version_id])

    unless @sidebar_page # Fallback to default sidebar
      @sidebar_wiki_entries = WikiPage.group_by_directory(@project_wiki.pages(limit: 15))
    end
  rescue ProjectWiki::CouldNotCreateWikiError
    flash[:notice] = "Could not create Wiki Repository at this time. Please try again later."
    redirect_to project_path(@project)
    false
  end

  def load_wiki
    ProjectWiki.new(@project, current_user)
  end

  def wiki_params
    params.require(:wiki).permit(:title, :content, :format, :message, :last_commit_sha)
  end

  def build_page(args)
    WikiPage.new(@project_wiki).tap do |page|
      page.update_attributes(args) # rubocop:disable Rails/ActiveRecordAliases
    end
  end

  def load_page
    @page ||= @project_wiki.find_page(*page_params)
  end

  def page_params
    keys = [:id]
    keys << :version_id if params[:action] == 'show'

    params.values_at(*keys)
  end

  def valid_encoding?
    strong_memoize(:valid_encoding) do
      @page.content.encoding == Encoding::UTF_8
    end
  end

  def set_encoding_error
    flash.now[:notice] = "The content of this page is not encoded in UTF-8. Edits can only be made via the Git repository."
  end
end
