defmodule PureAdminIconsWeb.ErrorHTML do
  @moduledoc """
  Styled error pages for icons.pureadmin.io.
  Self-contained HTML+CSS — no dependency on app assets or layouts.
  """
  use PureAdminIconsWeb, :html

  @messages %{
    400 => {"Bad Request", "The request could not be understood by the server."},
    403 => {"Forbidden", "You don't have permission to access this resource."},
    404 => {"Page Not Found", "The page you're looking for doesn't exist or may have been moved."},
    408 => {"Request Timeout", "The server timed out waiting for the request."},
    500 => {"Something Went Wrong", "We hit an unexpected error. The issue has been logged and we'll look into it."},
    502 => {"Bad Gateway", "The server received an invalid response from an upstream server."},
    503 => {"Service Unavailable", "The server is temporarily unavailable. Please try again in a moment."},
    504 => {"Gateway Timeout", "The server didn't respond in time. Please try again."}
  }

  def render(template, _assigns) do
    status = template |> String.split(".") |> List.first() |> String.to_integer()
    {title, message} = Map.get(@messages, status, {Phoenix.Controller.status_message_from_template(template), "An error occurred."})
    error_page(status, title, message)
  end

  defp error_page(status, title, message) do
    """
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>#{title} — icons.pureadmin.io</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap" rel="stylesheet" />
        <style>
          :root {
            --bg: oklch(18% 0.018 260);
            --fg: oklch(93% 0.01 260);
            --muted: oklch(55% 0.05 260);
            --primary: oklch(72% 0.19 60);
            --card: oklch(22% 0.02 260);
            --border: oklch(30% 0.02 260);
          }
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: 'Inter', system-ui, sans-serif;
            background: var(--bg);
            color: var(--fg);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 2rem;
          }
          .wrapper { text-align: center; max-width: 32rem; width: 100%; }
          .logo {
            font-size: 2.5rem;
            font-weight: 800;
            letter-spacing: -0.02em;
            margin-bottom: 2.5rem;
          }
          .logo-primary { color: var(--primary); }
          .card {
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 0.75rem;
            padding: 2.5rem 2rem;
          }
          .status {
            font-size: 5rem;
            font-weight: 800;
            color: var(--primary);
            line-height: 1;
            letter-spacing: -0.03em;
          }
          h1 {
            font-size: 1.25rem;
            font-weight: 600;
            margin-top: 0.75rem;
          }
          p {
            font-size: 0.875rem;
            color: var(--muted);
            margin-top: 0.75rem;
            line-height: 1.6;
          }
          .back {
            display: inline-block;
            margin-top: 1.75rem;
            padding: 0.6rem 1.5rem;
            background: var(--primary);
            color: var(--bg);
            font-size: 0.875rem;
            font-weight: 600;
            border-radius: 0.375rem;
            text-decoration: none;
            transition: opacity 0.15s;
          }
          .back:hover { opacity: 0.85; }
          .footer {
            margin-top: 2rem;
            font-size: 0.75rem;
            color: var(--muted);
          }
          .footer a { color: var(--primary); text-decoration: none; }
          .footer a:hover { text-decoration: underline; }
          .gh { position: fixed; top: 1.25rem; right: 1.25rem; color: var(--muted); transition: color 0.15s; }
          .gh:hover { color: var(--fg); }
          .gh svg { width: 1.75rem; height: 1.75rem; }
        </style>
        <script>
          (function(){
            var h=new Date().getHours(),r=document.documentElement.style;
            if(h>=5&&h<9){
              r.setProperty('--bg','oklch(96% 0.01 80)');r.setProperty('--fg','oklch(12% 0.015 260)');
              r.setProperty('--muted','oklch(38% 0.04 260)');r.setProperty('--card','oklch(91% 0.015 80)');
              r.setProperty('--border','oklch(84% 0.02 80)');
            }else if(h>=9&&h<20){
              r.setProperty('--bg','oklch(97% 0.005 260)');r.setProperty('--fg','oklch(12% 0.015 260)');
              r.setProperty('--muted','oklch(36% 0.04 260)');r.setProperty('--card','oklch(93% 0.008 260)');
              r.setProperty('--border','oklch(85% 0.012 260)');
            }else if(h>=20&&h<22){
              r.setProperty('--bg','oklch(30% 0.03 50)');r.setProperty('--fg','oklch(90% 0.015 60)');
              r.setProperty('--muted','oklch(50% 0.06 40)');r.setProperty('--card','oklch(25% 0.025 50)');
              r.setProperty('--border','oklch(35% 0.025 50)');
            }
          })();
        </script>
      </head>
      <body>
        <a href="https://github.com/KeenMate/pure-admin-icons" target="_blank" rel="noreferrer" class="gh" title="View on GitHub">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12"/></svg>
        </a>
        <div class="wrapper">
          <div class="logo">icons.<span class="logo-primary">pure</span>admin.io</div>
          <div class="card">
            <div class="status">#{status}</div>
            <h1>#{title}</h1>
            <p>#{message}</p>
            <a href="/" class="back">Back to icon search</a>
          </div>
          <div class="footer">
            Made by <a href="https://keenmate.com">KeenMate</a>
          </div>
        </div>
      </body>
    </html>
    """
    |> Phoenix.HTML.raw()
  end
end
