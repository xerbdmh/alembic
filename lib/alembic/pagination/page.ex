defmodule Alembic.Pagination.Page do
  @moduledoc """
  A page using paged pagination where the size of pages is fixed.
  """

  alias Alembic.{Document, Error, FromJson, Pagination, Source}

  # Constants

  @error_template %Error{
    source: %Source{
      pointer: "/page"
    }
  }

  @number_options %{
    field: :number,
    member: %{
      from_json: &__MODULE__.positive_integer_from_params/2,
      name: "number",
      required: true
    }
  }

  @size_options %{
    field: :size,
    member: %{
      from_json: &__MODULE__.positive_integer_from_params/2,
      name: "size",
      required: true
    }
  }

  @page_child_options_list [
    @number_options,
    @size_options
  ]

  # Struct

  defstruct number: 1,
            size: 10

  # Types

  @typedoc """
  * `number` - the 1-based page number
  * `size` - the size of this page and all pages
  """
  @type t :: %__MODULE__{
               number: pos_integer,
               size: pos_integer
             }

  # Functions

  @doc """
  The number of pages of `size` when there are `total_size` resources to be paginated.

  If there are no resources (`total_size` is `0`), then there will still be 1 page

      iex> Alembic.Pagination.Page.count(%{size: 10, total_size: 0})
      1

  The number of pages is always rounded up since a partial page still needs to be returned

      iex> Alembic.Pagination.Page.count(%{size: 10, total_size: 10})
      1
      iex> Alembic.Pagination.Page.count(%{size: 10, total_size: 1})
      1
      iex> Alembic.Pagination.Page.count(%{size: 10, total_size: 11})
      2

  """
  @spec count(%{size: pos_integer, total_size: non_neg_integer}) :: pos_integer
  def count(%{size: _, total_size: 0}), do: 1
  def count(%{size: size, total_size: total_size}) do
    total_size
    |> Kernel./(size)
    |> Float.ceil()
    |> round()
  end

  @doc """
  `t` for `Alembic.Pagination.t` `first`

  There is always a `first` `t` with `number` `1`.

      iex> Alembic.Pagination.Page.first(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 2,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      %Alembic.Pagination.Page{
        number: 1,
        size: 10
      }

  """
  @spec first(t, %{optional(:count) => pos_integer}) :: t
  def first(%__MODULE__{size: size}, _), do: %__MODULE__{number: 1, size: size}

  @doc """
  Parses `t` out of `params`

  ## No pagination

  If there is no `"page"` key, then there is no pagination.

      iex> Alembic.Pagination.Page.from_params(%{})
      {:ok, nil}

  ## Pagination

  If there is a "page" key with `"number"` and `"size"` children, then there is pagination.

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 1,
      ...>       "size" => 2
      ...>     }
      ...>   }
      ...> )
      {:ok, %Alembic.Pagination.Page{number: 1, size: 2}}

  In addition to be decoded JSON, the params can also be the raw `%{String.t => String.t}` and the quoted integers will
  be decoded.

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => "1",
      ...>       "size" => "2"
      ...>     }
      ...>   }
      ...> )
      {:ok, %Alembic.Pagination.Page{number: 1, size: 2}}

  ### Opt-out

  Opting out of default pagination can be indicated with a `nil` page

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{"page" => nil}
      ...> )
      {:ok, :all}

  ## Errors

  A page number can't be given as the `"page"` parameter alone because no default page size is assumed.

      iex> Alembic.Pagination.Page.from_params(%{"page" => 1})
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page` type is not object",
              meta: %{
                "type" => "object"
              },
              source: %Alembic.Source{
                pointer: "/page"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  ### Required parameters

  Likewise, the `"page"` map can't have only a `"number"` parameter because no default page size is assumed.

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 1
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/size` is missing",
              meta: %{
                "child" => "size"
              },
              source: %Alembic.Source{
                pointer: "/page"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  The page number is not assumed to be 1 when not given.

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "size" => 10
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/number` is missing",
              meta: %{
                "child" => "number"
              },
              source: %Alembic.Source{
                pointer: "/page"
              },
              status: "422",
              title: "Child missing"
            }
          ]
        }
      }

  ### Number format

  `"page"` `"number"` must be a positive integer.  It is 1-based.  The first page is `"1"`

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 0,
      ...>       "size" => 10
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/number` type is not positive integer",
              meta: %{
                "type" => "positive integer"
              },
              source: %Alembic.Source{
                pointer: "/page/number"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  ### Size format

  `"page"` `"size"` must be a positive integer.

      iex> Alembic.Pagination.Page.from_params(
      ...>   %{
      ...>     "page" => %{
      ...>       "number" => 1,
      ...>       "size" => 0
      ...>     }
      ...>   }
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "`/page/size` type is not positive integer",
              meta: %{
                "type" => "positive integer"
              },
              source: %Alembic.Source{
                pointer: "/page/size"
              },
              status: "422",
              title: "Type is wrong"
            }
          ]
        }
      }

  """
  @spec from_params(map) :: {:ok, t} | {:ok, :all} | {:ok, nil} | {:error, Document.t}

  def from_params(%{"page" => page}) when is_map(page) do
    parent = %{
      error_template: @error_template,
      json: page
    }

    @page_child_options_list
    |> Stream.map(&Map.put(&1, :parent, parent))
    |> Stream.map(&FromJson.from_parent_json_to_field_result/1)
    |> FromJson.reduce({:ok, %__MODULE__{}})
  end

  def from_params(%{"page" => nil}), do: {:ok, :all}

  def from_params(%{"page" => page}) when not is_map(page) do
    {:error, %Document{errors: [Error.type(@error_template, "object")]}}
  end

  def from_params(params) when is_map(params), do: {:ok, nil}

  @doc """
  Extracts `number` from `query` `"page[number]"` and and `size` from `query` `"page[size]"`.

      iex> Alembic.Pagination.Page.from_query("page%5Bnumber%5D=2&page%5Bsize%5D=10")
      %Alembic.Pagination.Page{number: 2, size: 10}

  If `query` does not have both `"page[number]"` and `"page[size]"` then `nil` is returned

      iex> Alembic.Pagination.Page.from_query("page%5Bnumber%5D=2")
      nil
      iex> Alembic.Pagination.Page.from_query("page%5Bsize%5D=10")
      nil
      iex> Alembic.Pagination.Page.from_query("")
      nil

  """
  @spec from_query(String.t) :: t
  def from_query(query) when is_binary(query) do
    reduced = query
              |> URI.query_decoder
              |> Enum.reduce(%__MODULE__{number: :unset, size: :unset}, &reduce_decoded_query_to_page/2)

    case reduced do
      %__MODULE__{number: number, size: size} when number == :unset or size == :unset ->
        nil
      set = %__MODULE__{} ->
        set
    end
  end

  @doc """
  Extracts `number` from `uri` `query` `"page[number]"` and `size` from `uri` `query` `"page[size]"`.

      iex> Alembic.Pagination.Page.from_uri(%URI{query: "page%5Bnumber%5D=2&page%5Bsize%5D=10"})
      %Alembic.Pagination.Page{number: 2, size: 10}

  If a `URI.t` `query` does not have both `"page[number]"` and `"page[size]"` then `nil` is returned

      iex> Alembic.Pagination.Page.from_uri(%URI{query: "page%5Bnumber%5D=2"})
      nil
      iex> Alembic.Pagination.Page.from_uri(%URI{query: "page%5Bsize%5D=10"})
      nil
      iex> Alembic.Pagination.Page.from_uri(%URI{query: ""})
      nil

  If a `URI.t` does not have a query then `nil` is returned

      iex> Alembic.Pagination.Page.from_uri(%URI{query: nil})
      nil

  """
  @spec from_uri(URI.t) :: t | nil
  def from_uri(uri)
  def from_uri(%URI{query: nil}), do: nil
  def from_uri(%URI{query: query}), do: from_query(query)

  @doc """
  `t` for `Alembic.Pagination.t` `last`

  There is always `last` `Alembic.Pagination.Page.t` with `number` `count`.

      iex> Alembic.Pagination.Page.last(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 1,
      ...>     size: 10
      ...>   },
      ...>   %{count: 2}
      ...> )
      %Alembic.Pagination.Page{
        number: 2,
        size: 10
      }

  """
  @spec last(t, %{required(:count) => pos_integer}) :: t
  def last(%__MODULE_{size: size}, %{count: count}), do: %__MODULE__{number: count, size: size}

  @doc """
  `t` for `Alembic.Pagination.t` `next`

  ## Single page

  When there is only one page, the first page is also the last page, so `next` is `nil`.

      iex> Alembic.Pagination.Page.next(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 1,
      ...>     size: 10
      ...>   },
      ...>   %{count: 1}
      ...> )
      nil

  ## Multiple Pages

  When there are multiple pages, the first page has the second page, with `number` `2`, as its next page.

      iex> Alembic.Pagination.Page.next(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 1,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      %Alembic.Pagination.Page{
        number: 2,
        size: 10
      }

  Any middle page will also have a next page with `number + 1`

      iex> Alembic.Pagination.Page.next(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 2,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      %Alembic.Pagination.Page{
        number: 3,
        size: 10
      }

  The last page is the only page that will have a next page.

      iex> Alembic.Pagination.Page.next(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 3,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      nil

  """
  @spec next(t, %{required(:count) => pos_integer}) :: t | nil
  # when not last page (or beyond)
  def next(%__MODULE__{number: number, size: size}, %{count: count}) when number < count do
    %__MODULE__{number: number + 1, size: size}
  end
  def next(_, _), do: nil

  @doc false
  def positive_integer_from_params(child, error_template) do
    with {:ok, integer} <- integer_from_params(child, error_template) do
      FromJson.integer_to_positive_integer(integer, error_template)
    end
  end

  @doc """
  `t` for `Alembic.Pagination.t` `previous`.

  ## Single page

  When there is only one page, the last page is also the first page, so previous page is `nil`.

      iex> Alembic.Pagination.Page.previous(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 1,
      ...>     size: 10
      ...>   },
      ...>   %{count: 1}
      ...> )
      nil

  ## Multiple Pages

  When there are multiple pages, the first page has no previous page, so it is `nil`.

      iex> Alembic.Pagination.Page.previous(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 1,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      nil

  Any middle page will have the previous page with `number - 1`.

      iex> Alembic.Pagination.Page.previous(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 2,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      %Alembic.Pagination.Page{
        number: 1,
        size: 10
      }

  The last page will also have previous page the same as a middle page.

      iex> Alembic.Pagination.Page.previous(
      ...>   %Alembic.Pagination.Page{
      ...>     number: 3,
      ...>     size: 10
      ...>   },
      ...>   %{count: 3}
      ...> )
      %Alembic.Pagination.Page{
        number: 2,
        size: 10
      }

  """
  @spec previous(t, %{optional(:count) => pos_integer}) :: t | nil
  def previous(%__MODULE__{number: number, size: size}, _) when number > 1 do
    %__MODULE__{number: number - 1, size: size}
  end
  def previous(_, _), do: nil

  @doc """
  `Alembic.Pagination.t` for pages around `page`.

  ## Single Page

  When there is only one page, `first` and `last` will be set to a `t`, but `next` or `previous` will be `nil`.

      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 1, size: 10},
      ...>   %{total_size: 5}
      ...> )
      {
        :ok,
        %Alembic.Pagination{
          first: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          last: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          total_size: 5
        }
      }

  ### No entries

  If `total_size` is `0`, then there will still be 1 page, but it will be empty

      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 1, size: 10},
      ...>   %{total_size: 0}
      ...> )
      {
        :ok,
        %Alembic.Pagination{
          first: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          last: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          total_size: 0
        }
      }

  ## Multiple Pages

  When there are multiple pages, every page will have `first` and `last` set to a `t`.

  On the first page, the `next` field will set, but not the `previous` field.

      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 1, size: 10},
      ...>   %{total_size: 25}
      ...> )
      {
        :ok,
        %Alembic.Pagination{
          first: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          last: %Alembic.Pagination.Page{
            number: 3,
            size: 10
          },
          next: %Alembic.Pagination.Page{
            number: 2,
            size: 10
          },
          total_size: 25
        }
      }

  On any middle page, both the `next` and `previous` fields will be set.

      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 2, size: 10},
      ...>   %{total_size: 25}
      ...> )
      {
        :ok,
        %Alembic.Pagination{
          first: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          last: %Alembic.Pagination.Page{
            number: 3,
            size: 10
          },
          next: %Alembic.Pagination.Page{
            number: 3,
            size: 10
          },
          previous: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          total_size: 25
        }
      }

  On the last page, the `previous` field will be set, but not the `next` field.

      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 3, size: 10},
      ...>   %{total_size: 25}
      ...> )
      {
        :ok,
        %Alembic.Pagination{
          first: %Alembic.Pagination.Page{
            number: 1,
            size: 10
          },
          last: %Alembic.Pagination.Page{
            number: 3,
            size: 10
          },
          previous: %Alembic.Pagination.Page{
            number: 2,
            size: 10
          },
          total_size: 25
        }
      }

  ## Out-of-range

  If a page number is too high an error will be returned.

      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 2, size: 10},
      ...>   %{total_size: 0}
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "Page number (2) must be between 1 and the page count (1)",
              meta: %{
                "count" => 1,
                "number" => 2
              },
              source: %Alembic.Source{
                pointer: "/page/number"
              },
              status: "422",
              title: "Page number must be between 1 and the page count"
            }
          ]
        }
      }
      iex> Alembic.Pagination.Page.to_pagination(
      ...>   %Alembic.Pagination.Page{number: 4, size: 10},
      ...>   %{total_size: 15}
      ...> )
      {
        :error,
        %Alembic.Document{
          errors: [
            %Alembic.Error{
              detail: "Page number (4) must be between 1 and the page count (2)",
              meta: %{
                "count" => 2,
                "number" => 4
              },
              source: %Alembic.Source{
                pointer: "/page/number"
              },
              status: "422",
              title: "Page number must be between 1 and the page count"
            }
          ]
        }
      }

  """
  @spec to_pagination(t, %{total_size: non_neg_integer}) :: {:ok, Pagination.t} | {:error, Document.t}
  def to_pagination(page = %__MODULE__{number: number, size: size}, %{total_size: total_size}) do
    count = count(%{size: size, total_size: total_size})

    if number > count do
      {
        :error,
        %Document{
          errors: [
            %Error{
              detail: "Page number (#{number}) must be between 1 and the page count (#{count})",
              meta: %{
                "count" => count,
                "number" => number
              },
              source: %Alembic.Source{
                pointer: "/page/number"
              },
              status: "422",
              title: "Page number must be between 1 and the page count"
            }
          ]
        }
      }
    else
      options = %{count: count}

      {
        :ok,
        %Pagination{
          first: first(page, options),
          last: last(page, options),
          next: next(page, options),
          previous: previous(page, options),
          total_size: total_size,
        }
      }
    end
  end

  @doc """
  Converts the `page` back to params.

  An `Alembic.Pagination.Page.t` is converted to JSON.

      iex> Alembic.Pagination.Page.to_params(%Alembic.Pagination.Page{number: 2, size: 10})
      %{
        "page" => %{
          "number" => 2,
          "size" => 10
        }
      }

  The special value `:all`, which indicates that pagination should be disabled and "all" pages should be returned at
  once goes back to a `nil` `"page"`

      iex> Alembic.Pagination.Page.to_params(:all)
      %{
        "page" => nil
      }

  A `nil` page on the other hand, has no params at all

      iex> Alembic.Pagination.Page.to_params(nil)
      %{}

  """
  @spec to_params(t | :all | nil) :: map
  def to_params(page)
  def to_params(:all), do: %{"page" => nil}
  def to_params(nil), do: %{}
  def to_params(%__MODULE__{number: number, size: size}) do
    %{
      "page" => %{
        "number" => number,
        "size" => size
      }
    }
  end

  @doc """
  Converts the `page` back to query portion of URI

      iex> Alembic.Pagination.Page.to_query(%Alembic.Pagination.Page{number: 2, size: 10})
      "page%5Bnumber%5D=2&page%5Bsize%5D=10"

  """
  @spec to_query(t) :: String.t
  def to_query(%__MODULE__{number: number, size: size}) do
    URI.encode_query ["page[number]": number, "page[size]": size]
  end

  ## Private Functions

  defp integer_from_params(
         quoted_integer,
         error_template = %Error{
           source: source = %Source{
             pointer: pointer
           }
         }
       ) when is_binary(quoted_integer) do
    case Integer.parse(quoted_integer) do
      :error ->
        {
          :error,
          %Document{
            errors: [
              Error.type(error_template, "quoted integer")
            ]
          }
        }
      {integer, ""} ->
        {:ok, integer}
      {integer, remainder_of_binary} ->
        {
          :error,
          %Document{
            errors: [
              %Error{
                detail: "`#{pointer}` contains quoted integer (`#{integer}`), " <>
                        "but also excess text (`#{inspect remainder_of_binary}`)",
                meta: %{
                  excess: remainder_of_binary,
                  integer: integer,
                  type: "quoted integer",
                },
                source: source,
                status: "422",
                title: "Excess text in quoted integer"
              }
            ]
          }
        }
    end
  end

  defp integer_from_params(integer, _) when is_integer(integer), do: {:ok, integer}

  defp integer_from_params(_, error_template) do
    {
      :error,
      %Document{
        errors: [
          Error.type(error_template, "integer")
        ]
      }
    }
  end

  defp reduce_decoded_query_to_page({"page[number]", encoded_page_number}, page = %__MODULE__{}) do
    %__MODULE__{page | number: String.to_integer(encoded_page_number)}
  end

  defp reduce_decoded_query_to_page({"page[size]", encoded_page_size}, page = %__MODULE__{}) do
    %__MODULE__{page | size: String.to_integer(encoded_page_size)}
  end

  defp reduce_decoded_query_to_page(_, page = %__MODULE__{}), do: page
end
