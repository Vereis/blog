defmodule Blog.Posts.InternalLinks do
  @moduledoc """
  Helper module for hydrating internal link scheme from the raw form:

    `href="#$(id)"`

  to the final form:

    `href="/posts/some_internal_link_scheme"`

  """

  alias Blog.Posts
  alias Blog.Posts.{InternalLink, Post}

  @internal_link_finder ~r/(href="#([^"]+)")/

  @spec hydrate_internal_links(%Post{}, [%InternalLink{}]) :: {:ok, %Post{}}
  def hydrate_internal_links(%Post{content: content} = post, internal_links) do
    hydrated_content =
      Enum.reduce(internal_links, content, fn %InternalLink{} = internal_link, content ->
        String.replace(content, internal_link.old_href, internal_link.new_href)
      end)

    {:ok, %Post{post | content: hydrated_content}}
  end

  @spec get_internal_links(%Post{}) :: {:ok, [%InternalLink{}]}
  def get_internal_links(%Post{content: content}) do
    links_by_id =
      @internal_link_finder
      |> Regex.scan(content, capture: :all_but_first)
      |> Map.new(fn [href, id] ->
        linked_post_id = id |> Integer.parse() |> elem(0)

        {linked_post_id,
         %InternalLink{
           old_href: href,
           linked_post_id: linked_post_id
         }}
      end)

    {:ok, linked_posts} = Posts.list_posts_where_id_in(Map.keys(links_by_id))

    internal_links =
      Enum.map(linked_posts, fn %Post{id: id, url: url} = post ->
        %InternalLink{
          links_by_id[id]
          | post: post,
            new_href: "href=\"#{url}\""
        }
      end)

    {:ok, internal_links}
  end
end
