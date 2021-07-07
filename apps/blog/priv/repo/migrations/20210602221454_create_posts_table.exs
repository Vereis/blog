defmodule Blog.Repo.Migrations.CreatePostsTable do
  use Ecto.Migration

  def change do
    create table(:posts) do
      add(:title, :string)
      add(:normalized_title, :string)

      add(:content, :text)
      add(:raw_content, :text)
      add(:description, :text)

      add(:reading_time_minutes, :integer)

      add(:created_at, :utc_datetime_usec)
      add(:updated_at, :utc_datetime_usec)

      add(:is_draft, :boolean)
      add(:tags, {:array, :string})
    end

    create(unique_index(:posts, [:normalized_title]))
  end
end
