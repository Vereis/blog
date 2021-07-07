defmodule Blog.PostsTest do
  use Blog.DataCase, async: true

  alias Blog.Posts
  alias Blog.Posts.Post

  @required_attrs %{
    id: 42,
    title: "some title",
    content: "some content",
    created_at: DateTime.utc_now(),
    updated_at: DateTime.utc_now(),
    tags: ["some_tag"],
    raw_content: "some raw content"
  }

  describe "create_post/1" do
    test "given valid attrs, inserts post to db" do
      assert {:ok, %Post{} = post} = Posts.create_post(@required_attrs)

      for {k, v} <- @required_attrs do
        assert Map.get(post, k) == v
      end
    end

    test "behaves idempotently when trying to create post twice" do
      assert {:ok, %Post{id: 42}} = Posts.create_post(@required_attrs)
      assert {:ok, %Post{id: 42}} = Posts.create_post(@required_attrs)

      # Also updates any fields that differ
      assert {:ok, %Post{id: 42, title: "something else"}} =
               Posts.create_post(%{@required_attrs | title: "something else"})
    end

    test "given invalid attrs, returns changeset error" do
      for {required_attr, _} <- @required_attrs do
        assert {:error, %Ecto.Changeset{errors: errors}} =
                 Posts.create_post(%{@required_attrs | required_attr => nil})

        assert {required_attr, {"can't be blank", [validation: :required]}} in errors
      end
    end
  end

  describe "update_post/2" do
    setup do
      {:ok, %Post{} = post} = Posts.create_post(@required_attrs)
      {:ok, post: post}
    end

    test "given valid updated fields, returns updated post", %{post: post} do
      new_title = Ecto.UUID.generate()
      assert {:ok, %Post{title: ^new_title}} = Posts.update_post(post, %{title: new_title})
    end

    test "given invalid attrs, returns changeset error", %{post: post} do
      for {required_attr, _} <- @required_attrs do
        assert {:error, %Ecto.Changeset{errors: errors}} =
                 Posts.update_post(post, %{@required_attrs | required_attr => nil})

        assert {required_attr, {"can't be blank", [validation: :required]}} in errors
      end
    end
  end

  describe "get_post_by_id/1" do
    setup do
      {:ok, %Post{} = post} = Posts.create_post(@required_attrs)
      {:ok, post: post}
    end

    test "given valid id, returns post", %{post: post} do
      assert {:ok, ^post} = Posts.get_post_by_id(post.id)
    end

    test "given invalid id, returns {:error, :not_found}" do
      assert {:error, :not_found} = Posts.get_post_by_id(1000)
    end
  end

  describe "list_posts/0" do
    setup do
      for id <- 1..10 do
        {:ok, %Post{}} =
          Posts.create_post(%{@required_attrs | id: id, title: Ecto.UUID.generate()})
      end

      {:ok, %Post{}} = Posts.create_post(%{@required_attrs | title: "Draft: some title"})

      :ok
    end

    test "returns a list of all posts, without returning draft posts" do
      assert {:ok, posts} = Posts.list_posts()
      assert is_list(posts)
      assert length(posts) == 10
      assert posts |> Enum.map(& &1.id) |> MapSet.new() |> MapSet.equal?(MapSet.new(1..10))
    end
  end

  describe "list_posts_with_tag/1" do
    setup do
      {:ok, %Post{} = post_1} =
        Posts.create_post(%{@required_attrs | id: 1, tags: [], title: Ecto.UUID.generate()})

      {:ok, %Post{} = post_2} =
        Posts.create_post(%{@required_attrs | id: 2, tags: ["1"], title: Ecto.UUID.generate()})

      {:ok, %Post{} = post_3} =
        Posts.create_post(%{@required_attrs | id: 3, tags: ["2"], title: Ecto.UUID.generate()})

      {:ok, %Post{} = post_4} =
        Posts.create_post(%{
          @required_attrs
          | id: 4,
            tags: ["1", "2"],
            title: Ecto.UUID.generate()
        })

      {:ok, %Post{} = post_5} =
        Posts.create_post(%{
          @required_attrs
          | id: 5,
            tags: ["1"],
            title: "Draft: test"
        })

      {:ok, post_1: post_1, post_2: post_2, post_3: post_3, post_4: post_4, post_5: post_5}
    end

    test "returns a list of all posts containing specified tags, without returning draft posts",
         state do
      assert {:ok, posts_tagged_1} = Posts.list_posts_with_tag("1")
      assert {:ok, posts_tagged_2} = Posts.list_posts_with_tag("2")

      assert length(posts_tagged_1) == 2
      assert state.post_2 in posts_tagged_1
      assert state.post_4 in posts_tagged_1

      assert length(posts_tagged_2) == 2
      assert state.post_3 in posts_tagged_2
      assert state.post_4 in posts_tagged_2

      # Since post 1 isn't tagged at all, it's not in either list
      refute state.post_1 in posts_tagged_1
      refute state.post_1 in posts_tagged_2

      # Since post 5 is a draft, despite being tagged 1, it isn't returned in either list
      refute state.post_5 in posts_tagged_1
      refute state.post_5 in posts_tagged_2
    end
  end

  describe "list_posts_where_id_in/1" do
    setup do
      for id <- 1..10 do
        {:ok, %Post{}} =
          Posts.create_post(%{@required_attrs | id: id, title: Ecto.UUID.generate()})
      end

      {:ok, %Post{}} = Posts.create_post(%{@required_attrs | id: 11, title: "Draft: some title"})

      :ok
    end

    test "returns all requested posts when given only valid ids" do
      assert {:ok, posts} = Posts.list_posts_where_id_in([1, 2, 3, 4, 5])
      assert is_list(posts)
      assert length(posts) == 5
      assert posts |> Enum.map(& &1.id) |> MapSet.new() |> MapSet.equal?(MapSet.new(1..5))
    end

    test "returns all requested posts, regardless of draft status" do
      assert {:ok, [%Post{id: 11, is_draft: true}]} = Posts.list_posts_where_id_in([11])
    end

    test "returns all requested posts that exist when given both valid and invalid ids" do
      assert {:ok, posts} = Posts.list_posts_where_id_in([1, 2, 3, 4, 5, 12, 13, 14, 15, 52])
      assert is_list(posts)
      assert length(posts) == 5
      assert posts |> Enum.map(& &1.id) |> MapSet.new() |> MapSet.equal?(MapSet.new(1..5))
    end
  end

  describe "process_internal_links/1" do
    setup do
      {:ok, %Post{} = post_without_internal_link} =
        Posts.create_post(%{@required_attrs | id: 1, title: "some title 1"})

      {:ok, %Post{} = post_with_internal_link} =
        Posts.create_post(%{
          @required_attrs
          | id: 2,
            content: "<a href=\"#1\">link</a>",
            title: "some title 2"
        })

      {:ok,
       post_with_internal_link: post_with_internal_link,
       post_without_internal_link: post_without_internal_link}
    end

    test "noop if post contains no internal links", %{
      post_without_internal_link: post_without_internal_link
    } do
      assert {:ok, ^post_without_internal_link} =
               Posts.process_internal_links(post_without_internal_link)
    end

    test "returns hydrated internal links when post contains internal links", %{
      post_with_internal_link: post_with_internal_link
    } do
      assert {:ok, %Post{content: "<a href=\"/posts/some_title_1\">link</a>"}} =
               Posts.process_internal_links(post_with_internal_link)
    end
  end
end
