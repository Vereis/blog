defmodule Blog.Posts.Poller do
  @moduledoc """
  Defines task which periodically polls GitHub's GraphQL API to fetch
  GitHub issues which get transformed into blog posts.
  """

  alias Blog.GraphQL

  alias Blog.Posts
  alias Blog.Posts.Post

  use Task

  # 5 minutes
  @timeout 5000 * 60

  @list_posts_query """
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) {
      issues(filterBy: {createdBy: $owner}, first: 100, orderBy: {field: CREATED_AT, direction: DESC}) {
        nodes {
          id: number
          content: bodyHTML
          raw_content: body
          created_at: createdAt
          updated_at: updatedAt
          title
          tags: labels(first: 10) {
            nodes {
              name
            }
          }
        }
        totalCount
        pageInfo {
          endCursor
          hasNextPage
        }
      }
    }
  }
  """

  def owner, do: Application.get_env(:blog, :owner)
  def name, do: Application.get_env(:blog, :repo)

  def start_link(_args) do
    Task.start_link(&task/0)
  end

  def task do
    fetch_posts()
    Process.sleep(@timeout)
    task()
  end

  def fetch_posts do
    posts =
      with {:ok, response} <- GraphQL.query(@list_posts_query, %{owner: owner(), name: name()}),
           {:ok, posts} <- build_posts_from_response(response) do
        for post <- posts do
          {:ok, %Post{} = post} = Posts.create_post(post)
          post
        end
      end

    {:ok, posts}
  end

  defp build_posts_from_response(%{
         "data" => %{"repository" => %{"issues" => %{"nodes" => nodes}}}
       }) do
    posts =
      Enum.map(nodes, fn %{"tags" => %{"nodes" => tags}} = node ->
        %{node | "tags" => Enum.map(tags, & &1["name"])}
      end)

    {:ok, posts}
  end
end
