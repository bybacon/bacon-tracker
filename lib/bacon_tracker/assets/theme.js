function initTheme() {
  const saved = localStorage.getItem('bt-theme');
  const sysDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = saved ? saved === 'dark' : sysDark;
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
  updateThemeBtn(isDark);
  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function (e) {
    if (!localStorage.getItem('bt-theme')) {
      const dark = e.matches;
      document.documentElement.dataset.theme = dark ? 'dark' : 'light';
      updateThemeBtn(dark);
    }
  });
}

function toggleTheme() {
  const isDark = document.documentElement.dataset.theme !== 'dark';
  document.documentElement.dataset.theme = isDark ? 'dark' : 'light';
  const sysDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  if (isDark === sysDark) {
    localStorage.removeItem('bt-theme');
  } else {
    localStorage.setItem('bt-theme', isDark ? 'dark' : 'light');
  }
  updateThemeBtn(isDark);
}

function updateThemeBtn(isDark) {
  document.querySelectorAll('.theme-toggle').forEach((b) => {
    b.textContent = isDark ? '◑' : '◐';
    b.title = isDark ? 'light mode' : 'dark mode';
  });
}
