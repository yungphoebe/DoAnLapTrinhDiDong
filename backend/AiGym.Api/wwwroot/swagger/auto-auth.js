(function () {
  const loginPath = '/api/auth/login';

  function authorize(token) {
    const ui = window.ui;
    if (!ui || !ui.authActions || !token) return;

    ui.authActions.authorize({
      Bearer: {
        name: 'Bearer',
        schema: {
          type: 'http',
          in: 'header',
          name: 'Authorization',
          scheme: 'bearer',
          bearerFormat: 'JWT'
        },
        value: token
      }
    });
  }

  function showHint(email) {
    const existing = document.getElementById('aigym-swagger-token-hint');
    if (existing) existing.remove();

    const hint = document.createElement('div');
    hint.id = 'aigym-swagger-token-hint';
    hint.textContent = `Dang nhap thanh cong${email ? `: ${email}` : ''}. Token da duoc gan vao Authorize, bay gio co the sua/xoa post.`;
    hint.style.cssText = [
      'position:fixed',
      'right:16px',
      'bottom:16px',
      'z-index:9999',
      'max-width:360px',
      'padding:12px 14px',
      'border-radius:8px',
      'background:#123524',
      'color:#fff',
      'box-shadow:0 8px 24px rgba(0,0,0,.18)',
      'font-family:Arial,sans-serif',
      'font-size:13px'
    ].join(';');
    document.body.appendChild(hint);
    window.setTimeout(() => hint.remove(), 7000);
  }

  const originalFetch = window.fetch;
  window.fetch = async function (input, init) {
    const response = await originalFetch.apply(this, arguments);
    try {
      const url = typeof input === 'string' ? input : input && input.url;
      if (url && url.endsWith(loginPath) && response.ok) {
        const clone = response.clone();
        const body = await clone.json();
        if (body.token) {
          authorize(body.token);
          showHint(body.email);
        }
      }
    } catch (_) {
      // Swagger must keep working even if the helper cannot parse a response.
    }
    return response;
  };
})();
