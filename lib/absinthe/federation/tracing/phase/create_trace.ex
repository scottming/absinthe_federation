defmodule Absinthe.Federation.Tracing.Pipeline.Phase.CreateTrace do
  use Absinthe.Phase

  def run(blueprint, options \\ [])

  def run(%Absinthe.Blueprint{execution: %{acc: acc}} = blueprint, _options) do
    trace =
      Absinthe.Federation.Trace.new(%{
        # Wallclock time when the trace started.
        start_time: Absinthe.Federation.Tracing.Timestamp.now!()
      })

    new_acc =
      acc
      # TODO: detect `apollo-federation-include-trace` header to enable tracing
      |> Map.put(:federation_tracing_enabled, true)
      |> Map.put(:federation_trace, trace)
      |> Map.put(:federation_tracing_start_time, System.monotonic_time(:nanosecond))

    {:ok, put_in(blueprint.execution.acc, new_acc)}
  end

  def run(blueprint, _options), do: {:ok, blueprint}
end
