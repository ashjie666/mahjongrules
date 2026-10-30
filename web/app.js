(function () {
  "use strict";

  var STORAGE_KEY = "site:theme";
  var root = document.documentElement;

  // theme toggle
  var toggle = document.getElementById("theme-toggle");
  if (toggle) {
    toggle.addEventListener("click", function () {
      var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      root.setAttribute("data-theme", next);
      try { localStorage.setItem(STORAGE_KEY, next); } catch (e) {}
    });
  }

  // mobile menu
  var menuBtn = document.getElementById("menu-toggle");
  var nav = document.getElementById("main-nav");
  if (menuBtn && nav) {
    menuBtn.addEventListener("click", function () {
      var open = nav.classList.toggle("is-open");
      menuBtn.setAttribute("aria-expanded", open ? "true" : "false");
    });
    document.addEventListener("keydown", function (e) {
      if (e.key === "Escape" && nav.classList.contains("is-open")) {
        nav.classList.remove("is-open");
        menuBtn.setAttribute("aria-expanded", "false");
        menuBtn.focus();
      }
    });
  }

  // newsletter: posts to Getform with fetch, so the page never navigates away
  var forms = document.querySelectorAll(".nl-form");
  Array.prototype.forEach.call(forms, function (form) {
    var input = form.querySelector('input[type="email"]');
    var btn = form.querySelector('button[type="submit"]');
    var status = form.parentNode.querySelector(".subscribe-status");
    var idleLabel = btn ? btn.textContent : "";
    var busy = false;

    function fail() {
      if (status) {
        status.innerHTML = 'Could not send. Email <a href="mailto:yqin1090@gmail.com">yqin1090@gmail.com</a> and I will add you manually.';
      }
    }

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (busy) return;
      var email = input ? input.value.trim() : "";
      if (!email || email.indexOf("@") < 1) {
        if (status) status.textContent = "Please enter a valid email address.";
        if (input) input.focus();
        return;
      }

      busy = true;
      if (btn) { btn.disabled = true; btn.textContent = "Sending…"; }
      if (status) status.textContent = "";

      fetch(form.action, {
        method: "POST",
        headers: { Accept: "application/json" },
        body: new FormData(form)
      })
        .then(function (r) {
          if (!r.ok) throw new Error("http " + r.status);
          return r.json();
        })
        .then(function (data) {
          if (!data || data.success !== true) throw new Error("rejected");
          if (btn) btn.textContent = "Done…";
          if (status) status.textContent = "You are on the list. I will write when the next guide goes live.";
          form.reset();
        })
        .catch(function () {
          if (btn) btn.textContent = idleLabel;
          fail();
        })
        .then(function () {
          busy = false;
          if (btn) btn.disabled = false;
        });
    });
  });

  // mark the nav link that matches the current path
  var path = window.location.pathname.replace(/\.html$/, "").replace(/\/$/, "") || "/";
  Array.prototype.forEach.call(document.querySelectorAll("#main-nav a"), function (a) {
    var href = a.getAttribute("href") || "";
    if (href === path || (path === "/" && href === "/")) {
      a.setAttribute("aria-current", "page");
    }
  });
})();
