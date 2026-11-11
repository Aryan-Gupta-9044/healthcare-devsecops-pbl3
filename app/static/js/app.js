(function () {
  "use strict";
  var rows = document.getElementById("rows");
  var msg = document.getElementById("msg");

  function cell(tr, text, cls) {
    var td = document.createElement("td");
    if (cls) {
      var s = document.createElement("span");
      s.className = "pill " + cls;
      s.textContent = text;
      td.appendChild(s);
    } else {
      td.textContent = text;
    }
    tr.appendChild(td);
  }

  function loadPatients() {
    return fetch("/api/patients").then(function (r) { return r.json(); }).then(function (list) {
      rows.textContent = "";
      list.forEach(function (p) {
        var tr = document.createElement("tr");
        cell(tr, p.id); cell(tr, p.name); cell(tr, String(p.age)); cell(tr, p.department); cell(tr, p.status, p.status);
        rows.appendChild(tr);
      });
    });
  }

  function loadStats() {
    return fetch("/api/stats").then(function (r) { return r.json(); }).then(function (s) {
      document.getElementById("st-total").textContent = s.total;
      document.getElementById("st-sched").textContent = s.by_status["Scheduled"];
      document.getElementById("st-in").textContent = s.by_status["Checked-In"];
      document.getElementById("st-done").textContent = s.by_status["Completed"];
      document.getElementById("st-avg").textContent = s.average_age;
    });
  }

  document.getElementById("patient-form").addEventListener("submit", function (e) {
    e.preventDefault();
    var f = e.target;
    var body = { name: f.name.value, age: f.age.value, department: f.department.value, status: f.status.value };
    fetch("/api/patients", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
      .then(function (r) { return r.json().then(function (j) { return { ok: r.ok, j: j }; }); })
      .then(function (res) {
        msg.textContent = res.ok ? "Registered " + res.j.id : "Error: " + res.j.error;
        if (res.ok) { f.reset(); loadPatients(); loadStats(); }
      })
      .catch(function () { msg.textContent = "Network error"; });
  });

  loadPatients(); loadStats();
})();
