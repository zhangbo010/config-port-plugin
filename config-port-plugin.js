/**
 * Mainsail/Fluidd 配置端口插件
 * 端口 80 访问时隐藏配置相关按钮，端口 5337 访问时显示
 */
(function () {
  'use strict';

  const CONFIG_PORT = '5337';

  function shouldShowConfig() {
    return (window.location.port || '80') === CONFIG_PORT;
  }

  if (shouldShowConfig()) return;

  const style = document.createElement('style');
  style.id = 'config-port-plugin-styles';
  style.textContent = '[data-config-port-hidden] { display: none !important; }';
  document.head.appendChild(style);

  const selectors = [
    'a[href="/config"]', 'a[href="/config/"]',
    'a[href="/configure"]', 'a[href="/configure/"]',
    'a[href="/system"]', 'a[href="/system/"]',
    'a[href="/settings"]', 'a[href="/settings/"]', 'a[href^="/settings/"]',
  ];

  function hide() {
    selectors.forEach(sel => {
      document.querySelectorAll(sel).forEach(el => {
        const item = el.closest('.v-list-item') || el.closest('a') || el;
        if (item && !item.hasAttribute('data-config-port-hidden')) {
          item.setAttribute('data-config-port-hidden', 'true');
        }
      });
    });
  }

  function run() {
    hide();
    new MutationObserver(hide).observe(document.body, { childList: true, subtree: true });
  }

  document.body ? run() : document.addEventListener('DOMContentLoaded', run);
})();
