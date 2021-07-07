defmodule Blog.Posts.InternalLinksTest do
  use Blog.DataCase, async: true

  alias Blog.Posts
  alias Blog.Posts.{InternalLink, InternalLinks, Post}

  @required_attrs %{
    id: 42,
    title: "some title",
    content: "some content",
    created_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now(),
    tags: ["some_tag"],
    raw_content: "some raw content"
  }

  setup do
    {:ok, %Post{} = post_without_internal_link} =
      Posts.create_post(%{@required_attrs | id: 1, title: Ecto.UUID.generate()})

    {:ok, %Post{} = post_with_internal_link} =
      Posts.create_post(%{
        @required_attrs
        | id: 2,
          content: "<a href=\"#1\"></a><a href=\"#2\"></a><a href=\"#42\"></a>",
          title: Ecto.UUID.generate()
      })

    {:ok,
     post_with_internal_link: post_with_internal_link,
     post_without_internal_link: post_without_internal_link}
  end

  describe "get_internal_links/1" do
    test "given post without internal links, returns empty list", %{
      post_without_internal_link: post_without_internal_link
    } do
      assert {:ok, []} = InternalLinks.get_internal_links(post_without_internal_link)
    end

    test "given post with internal links, returns list of links", %{
      post_with_internal_link: post_with_internal_link
    } do
      assert {:ok, links} = InternalLinks.get_internal_links(post_with_internal_link)
      assert length(links) == 2

      link_ids = Enum.map(links, fn %InternalLink{linked_post_id: link_id} -> link_id end)

      # These post_ids exist in the DB, so if they appear in a href tag they're
      # treated as internal links
      for expected_link_id <- [1, 2] do
        assert expected_link_id in link_ids
      end

      # ID `42` exists in the content of the post, but isn't a valid ID so won't
      # be returned as an internal link:
      refute 42 in link_ids
    end
  end

  describe "hydrate_internal_links/2" do
    setup do
      {:ok,
       internal_links: [
         %InternalLink{linked_post_id: 1, new_href: "href=\"test\"", old_href: "href=\"#1\""}
       ]}
    end

    test "noop when given post without internal links, despite being given an internal link struct",
         %{
           post_without_internal_link: post_without_internal_link,
           internal_links: internal_links
         } do
      assert {:ok, ^post_without_internal_link} =
               InternalLinks.hydrate_internal_links(post_without_internal_link, internal_links)
    end

    test "noop when given post with internal links, but no internal links",
         %{
           post_with_internal_link: post_with_internal_link
         } do
      assert {:ok, ^post_with_internal_link} =
               InternalLinks.hydrate_internal_links(post_with_internal_link, [])
    end

    test "replaces all occurences of an `internal_link.old_href` with the `new_href` in a post's content",
         %{
           post_with_internal_link: post_with_internal_link,
           internal_links: internal_links
         } do
      assert {:ok, %Post{content: updated_content}} =
               InternalLinks.hydrate_internal_links(post_with_internal_link, internal_links)

      assert updated_content == "<a href=\"test\"></a><a href=\"#2\"></a><a href=\"#42\"></a>"
    end
  end
end
