/**
 * Mainsail/Fluidd 配置端口插件
 * 端口 80 访问时隐藏配置功能，端口 5337 访问时显示配置
 */
(function () {
  'use strict';

  const CONFIG_PORT = '5337';
  const RESTRICTED_PATHS = ['/config', '/configure', '/system', '/settings'];

  function getCurrentPort() {
    return window.location.port || '80';
  }

  function shouldShowConfig() {
    return getCurrentPort() === CONFIG_PORT;
  }

  function isRestrictedPath(path) {
    return RESTRICTED_PATHS.some(p => path === p || path.startsWith(p + '/'));
  }

  // 路由拦截：访问配置页时重定向到首页
  function setupRouteGuard() {
    if (shouldShowConfig()) return;

    const checkAndRedirect = () => {
      if (isRestrictedPath(window.location.pathname)) {
        window.location.replace('/');
      }
    };

    window.addEventListener('popstate', checkAndRedirect);
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', checkAndRedirect);
    } else {
      checkAndRedirect();
    }
    // 定期检查，防止通过 Vue Router 等 SPA 导航进入配置页
    setInterval(checkAndRedirect, 500);
  }

  // 隐藏侧边栏中的配置相关菜单项
  function hideConfigNavItems() {
    const style = document.createElement('style');
    style.id = 'config-port-plugin-styles';
    style.textContent = `
      /* 隐藏配置相关菜单项 */
      [data-config-port-hidden] { display: none !important; }
    `;
    document.head.appendChild(style);

    const selectors = [
      // Mainsail: Machine 配置页 /config
      'a[href="/config"]',
      'a[href="/config/"]',
      // Fluidd: Configure /configure, System /system, Settings /settings
      'a[href="/configure"]',
      'a[href="/configure/"]',
      'a[href="/system"]',
      'a[href="/system/"]',
      'a[href="/settings"]',
      'a[href="/settings/"]',
      'a[href^="/settings/"]',
    ];

    const hideElements = () => {
      selectors.forEach(sel => {
        try {
          document.querySelectorAll(sel).forEach(el => {
            const item = el.closest('.v-list-item') || el.closest('a') || el;
            if (item && !item.hasAttribute('data-config-port-hidden')) {
              item.setAttribute('data-config-port-hidden', 'true');
              item.style.display = 'none';
            }
          });
        } catch (_) {}
      });
    };

    const observer = new MutationObserver(() => {
      hideElements();
    });

    const run = () => {
      hideElements();
      observer.observe(document.body, {
        childList: true,
        subtree: true,
      });
    };

    if (document.body) {
      run();
    } else {
      document.addEventListener('DOMContentLoaded', run);
    }
  }

  function init() {
    if (shouldShowConfig()) {
      return; // 5337 端口，显示所有配置
    }

    setupRouteGuard();
    hideConfigNavItems();
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
