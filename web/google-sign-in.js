(function () {
  let loading;
  let initializedClient;
  let active;

  function loadGoogle() {
    if (window.google?.accounts?.id) return Promise.resolve();
    if (loading) return loading;
    loading = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      const timer = setTimeout(() => {
        script.remove();
        loading = undefined;
        reject(new Error('Google load timed out'));
      }, 15000);
      script.src = 'https://accounts.google.com/gsi/client';
      script.async = true;
      script.onload = () => { clearTimeout(timer); resolve(); };
      script.onerror = () => {
        clearTimeout(timer);
        script.remove();
        loading = undefined;
        reject(new Error('Google unavailable'));
      };
      document.head.appendChild(script);
    });
    return loading;
  }

  window.gymGoogleSignIn = {
    async render(element, clientId, callback) {
      await loadGoogle();
      // Flutter creates platform-view elements before attaching them to the DOM.
      // GIS needs a connected element to measure and render its iframe.
      for (let attempt = 0; !element.isConnected && attempt < 120; attempt++) {
        await new Promise(resolve => setTimeout(resolve, 16));
      }
      if (!element.isConnected) return;
      active = { element, callback };
      if (initializedClient !== clientId) {
        window.google.accounts.id.initialize({
          client_id: clientId,
          auto_select: false,
          button_auto_select: false,
          ux_mode: 'popup',
          callback: response => {
            if (active?.element.isConnected && response.credential) {
              active.callback(response.credential);
            }
          },
        });
        initializedClient = clientId;
      }
      window.google.accounts.id.renderButton(element, {
        type: 'icon', theme: 'outline', size: 'large', shape: 'rectangular',
        locale: 'vi',
      });
    },
  };
})();
