defmodule Absinthe.Federation.TracingTests do
  use Absinthe.Federation.Case, async: true

  defmodule TestSchema do
    use Absinthe.Schema
    use Absinthe.Federation.Tracing

    object :person do
      field(:name, :string)
      field(:age, non_null(:integer))
      field(:cars, list_of(:car))
    end

    object :car do
      field(:make, non_null(:string))
      field(:model, non_null(:string))
    end

    query do
      field :get_person, list_of(non_null(:person)) do
        resolve(fn _, _ ->
          {:ok,
           [
             %{
               name: "sikan",
               age: nil,
               cars: [%{make: "Honda", model: "Civic"}]
             }
           ]}
        end)
      end
    end
  end

  test "should have :ftv1 in extensions" do
    query = """
    query {
      getPerson {
        name
        cars {
          make
          model
        }
      }
    }
    """

    %{extensions: extensions} = get_result(TestSchema, query)
    assert Map.has_key?(extensions, :ftv1)
  end

  test "alias has original_field_name set correctly" do
    query = """
    query {
      getPerson {
        personName: name
      }
    }
    """

    %{root: %{child: [%{child: [%{child: [%{id: id, original_field_name: original_field_name}]}]}]}} =
      get_trace(TestSchema, query)

    assert id == {:response_name, "personName"}
    assert original_field_name == "name"
  end

  test "sets root trace fields" do
    query = """
    query { getPerson { name } }
    """

    %{start_time: start_time, end_time: end_time, duration_ns: duration_ns} = get_trace(TestSchema, query)

    refute is_nil(start_time)
    refute is_nil(end_time)
    refute is_nil(duration_ns)
  end

  test "sets trace node fields" do
    query = """
    query { getPerson { name } }
    """

    %{root: %{child: [get_person_trace_node]}} = get_trace(TestSchema, query)
    %{id: id, start_time: start_time, end_time: end_time, parent_type: parent_type, type: type} = get_person_trace_node

    assert id == {:response_name, "getPerson"}
    refute is_nil(start_time)
    refute is_nil(end_time)
    assert parent_type == "RootQueryType"
    assert type == "[Person!]"
  end

  test "sets trace node error fields" do
    query = """
    query { getPerson { age } }
    """

    %{root: %{child: [%{child: [person_node]}]}} = get_trace(TestSchema, query)
    %{id: id, error: errors} = person_node

    assert id == {:response_name, "age"}
    refute Enum.empty?(errors)
  end

  defp get_result(schema, query) do
    pipeline = Absinthe.Federation.Tracing.Pipeline.default(schema, [])

    query
    |> Absinthe.Pipeline.run(pipeline)
    |> case do
      {:ok, %{result: result}, _} -> result
      error -> error
    end
  end

  defp get_trace(schema, query) do
    schema
    |> get_result(query)
    |> Map.get(:extensions, %{})
    |> Map.get(:ftv1, "")
    |> Base.decode64!()
    |> Absinthe.Federation.Trace.decode()
  end
end
