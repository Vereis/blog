defmodule Blog.Posts do
  @moduledoc """
  Top level context for posts
  """

  alias Blog.Posts.{InternalLinks, Post}
  alias Blog.Repo

  @spec get_post_by_id(id :: number()) :: {:ok, %Post{}} | {:error, term()}
  def get_post_by_id(id) do
    Post.base_query()
    |> Post.where_id(id)
    |> Repo.one()
    |> case do
      %Post{} = post ->
        {:ok, post}

      nil ->
        {:error, :not_found}
    end
  end

  @spec get_post_by_title(title :: String.t()) :: {:ok, %Post{}} | {:error, term()}
  def get_post_by_title(title) when is_binary(title) do
    Post.base_query()
    |> Post.where_normalized_title(title)
    |> Repo.one()
    |> case do
      %Post{} = post ->
        {:ok, post}

      nil ->
        {:error, :not_found}
    end
  end

  @spec list_posts :: {:ok, [%Post{}]}
  def list_posts do
    posts =
      Post.base_query()
      |> Post.where_is_draft(false)
      |> Post.order_by_created_at()
      |> Repo.all()

    {:ok, posts}
  end

  @spec list_posts_with_tag(tag :: String.t()) :: {:ok, [%Post{}]}
  def list_posts_with_tag(tag) do
    posts =
      Post.base_query()
      |> Post.where_has_tag(tag)
      |> Post.where_is_draft(false)
      |> Post.order_by_created_at()
      |> Repo.all()

    {:ok, posts}
  end

  @spec list_posts_where_id_in([id :: number()]) :: {:ok, [%Post{}]}
  def list_posts_where_id_in(ids) do
    posts =
      Post.base_query()
      |> Post.where_id_in(ids)
      |> Repo.all()

    {:ok, posts}
  end

  @spec create_post(params :: map()) :: {:ok, %Post{}} | {:error, term()}
  def create_post(params) do
    %Post{}
    |> Post.changeset(params)
    |> Repo.insert(on_conflict: :replace_all, conflict_target: :id)
  end

  @spec update_post(post :: %Post{}, params :: map()) :: {:ok, %Post{}} | {:error, term()}
  def update_post(%Post{} = post, params) do
    post
    |> Post.changeset(params)
    |> Repo.update()
  end

  @spec process_internal_links(%Post{}) :: {:ok, %Post{}}
  def process_internal_links(%Post{} = post) do
    with {:ok, internal_links} <- InternalLinks.get_internal_links(post),
         {:ok, post} <- InternalLinks.hydrate_internal_links(post, internal_links) do
      {:ok, post}
    end
  end
end
