defmodule RentBotWeb.ErrorJSON do
  # If you want to customize a particular status code,
  # you can add your own clauses for specific statuses.
  def render(template, _assigns) do
    %{errors: %{detail: Phoenix.Controller.status_message_from_template(template)}}
  end
end
