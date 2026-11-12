/**
 * Healthcare Inpatient SQL Analytics Portfolio
 * Interactive Visualizations & Data Layer
 * Designed with Chart.js using User Palette:
 * Buttercup Sky, Dewy Blue, Sunwashed, Cloud Puff, Morning Breeze
 */

document.addEventListener('DOMContentLoaded', () => {
  initMobileNav();
  initCaseStudyTabs();
  initCodeCopy();
  loadAnalyticsDataAndRender();
});

// Mobile Navigation
function initMobileNav() {
  const toggle = document.querySelector('.mobile-toggle');
  const navLinks = document.querySelector('.nav-links');
  if (toggle && navLinks) {
    toggle.addEventListener('click', () => {
      navLinks.classList.toggle('open');
      const isOpen = navLinks.classList.contains('open');
      toggle.setAttribute('aria-expanded', isOpen);
    });

    document.querySelectorAll('.nav-link').forEach(link => {
      link.addEventListener('click', () => navLinks.classList.remove('open'));
    });
  }
}

// Case Studies Tab Switching
function initCaseStudyTabs() {
  const tabs = document.querySelectorAll('.case-tab-btn');
  const panels = document.querySelectorAll('.case-panel');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetId = tab.getAttribute('data-target');
      
      tabs.forEach(t => t.classList.remove('active'));
      panels.forEach(p => p.classList.remove('active'));

      tab.classList.add('active');
      const activePanel = document.getElementById(targetId);
      if (activePanel) activePanel.classList.add('active');
    });
  });
}

// Code Copy Button
function initCodeCopy() {
  document.querySelectorAll('.btn-copy').forEach(btn => {
    btn.addEventListener('click', () => {
      const codeBlock = btn.closest('.code-box')?.querySelector('code');
      if (codeBlock) {
        navigator.clipboard.writeText(codeBlock.innerText).then(() => {
          const origText = btn.innerText;
          btn.innerText = 'Copied!';
          btn.style.backgroundColor = '#2E7D32';
          btn.style.borderColor = '#2E7D32';
          setTimeout(() => {
            btn.innerText = origText;
            btn.style.backgroundColor = '';
            btn.style.borderColor = '';
          }, 2000);
        });
      }
    });
  });
}

// Palette Theme for Chart.js
const PALETTE = {
  buttercupSky: '#FFF2B2',
  dewyBlue: '#A8C6E7',
  sunwashed: '#FFE08A',
  cloudPuff: '#FFF7D6',
  morningBreeze: '#7FA8D6',
  brandDark: '#1E3550',
  brandPrimary: '#4C78B2',
  emergencyRed: '#E57373',
  slateMuted: '#94A3B8'
};

// Global Chart Defaults
if (window.Chart) {
  Chart.defaults.font.family = "'Inter', -apple-system, BlinkMacSystemFont, sans-serif";
  Chart.defaults.color = '#536475';
  Chart.defaults.plugins.tooltip.backgroundColor = '#1E3550';
  Chart.defaults.plugins.tooltip.titleColor = '#FFFFFF';
  Chart.defaults.plugins.tooltip.bodyColor = '#E2E8F0';
  Chart.defaults.plugins.tooltip.padding = 10;
  Chart.defaults.plugins.tooltip.cornerRadius = 6;
  Chart.defaults.plugins.legend.labels.usePointStyle = true;
}

// Fetch Data and Render Visualizations
async function loadAnalyticsDataAndRender() {
  try {
    const [conditions, insurance, admissionTypes, monthlyTrends, losDist, topHospitals] = await Promise.all([
      fetchData('assets/data/conditions.json'),
      fetchData('assets/data/insurance.json'),
      fetchData('assets/data/admission_types.json'),
      fetchData('assets/data/monthly_trends.json'),
      fetchData('assets/data/los_distribution.json'),
      fetchData('assets/data/top_hospitals.json')
    ]);

    renderConditionsChart(conditions);
    renderAdmissionTypeChart(admissionTypes);
    renderMonthlyTrendsChart(monthlyTrends);
    renderInsuranceChart(insurance);
    renderLosChart(losDist);
    renderHospitalChart(topHospitals);
  } catch (err) {
    console.warn('Data fetch fallback used. Rendering charts from embedded cache.', err);
    renderFallbackCharts();
  }
}

async function fetchData(url) {
  const resp = await fetch(url);
  if (!resp.ok) throw new Error(`HTTP error! status: ${resp.status}`);
  return await resp.json();
}

// 1. Medical Conditions Chart
function renderConditionsChart(data) {
  const ctx = document.getElementById('chartConditions')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.medical_condition),
      datasets: [
        {
          label: 'Encounter Volume',
          data: data.map(d => d.records),
          backgroundColor: PALETTE.dewyBlue,
          borderColor: PALETTE.morningBreeze,
          borderWidth: 1,
          borderRadius: 4,
          yAxisID: 'y'
        },
        {
          label: 'Total Billing ($M)',
          data: data.map(d => (d.total_billing / 1e6).toFixed(2)),
          type: 'line',
          borderColor: '#E6A23C',
          backgroundColor: PALETTE.sunwashed,
          pointBackgroundColor: '#E6A23C',
          borderWidth: 2,
          tension: 0.2,
          yAxisID: 'y1'
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      scales: {
        y: {
          title: { display: true, text: 'Encounter Count' },
          grid: { color: '#F1F5F9' }
        },
        y1: {
          position: 'right',
          title: { display: true, text: 'Billed Charges ($M)' },
          grid: { drawOnChartArea: false }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// 2. Admission Type Donut Chart
function renderAdmissionTypeChart(data) {
  const ctx = document.getElementById('chartAdmissionType')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'doughnut',
    data: {
      labels: data.map(d => `${d.admission_type} (${d.pct_records}%)`),
      datasets: [{
        data: data.map(d => d.records),
        backgroundColor: [
          PALETTE.morningBreeze,
          PALETTE.sunwashed,
          PALETTE.emergencyRed
        ],
        borderWidth: 2,
        borderColor: '#FFFFFF'
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { position: 'bottom' }
      },
      cutout: '65%'
    }
  });
}

// 3. Monthly Trends Timeline
function renderMonthlyTrendsChart(data) {
  const ctx = document.getElementById('chartMonthlyTrends')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'line',
    data: {
      labels: data.map(d => d.month),
      datasets: [
        {
          label: 'Monthly Admissions',
          data: data.map(d => d.admissions),
          borderColor: PALETTE.morningBreeze,
          backgroundColor: 'rgba(127, 168, 214, 0.12)',
          fill: true,
          tension: 0.25,
          borderWidth: 2,
          pointRadius: 2,
          pointHoverRadius: 5
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        tooltip: {
          callbacks: {
            footer: (items) => {
              const idx = items[0].dataIndex;
              return `Billing: $${(data[idx].total_billing / 1e6).toFixed(2)}M | Emergency: ${data[idx].emergency_pct}%`;
            }
          }
        }
      },
      scales: {
        y: {
          title: { display: true, text: 'Admissions / Month' },
          grid: { color: '#F1F5F9' }
        },
        x: {
          ticks: { maxTicksLimit: 12 },
          grid: { display: false }
        }
      }
    }
  });
}

// 4. Insurance Carrier Breakdown
function renderInsuranceChart(data) {
  const ctx = document.getElementById('chartInsurance')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.insurance_provider),
      datasets: [{
        label: 'Gross Billed Charges ($M)',
        data: data.map(d => (d.total_billing / 1e6).toFixed(2)),
        backgroundColor: [
          PALETTE.dewyBlue,
          PALETTE.morningBreeze,
          PALETTE.sunwashed,
          PALETTE.buttercupSky,
          '#B5D0EE'
        ],
        borderWidth: 1,
        borderColor: '#94B4D8',
        borderRadius: 4
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: {
          title: { display: true, text: 'Billed Charges ($M USD)' },
          grid: { color: '#F1F5F9' }
        },
        y: { grid: { display: false } }
      }
    }
  });
}

// 5. Length of Stay Distribution
function renderLosChart(data) {
  const ctx = document.getElementById('chartLos')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.los_tier),
      datasets: [{
        label: 'Encounter Count',
        data: data.map(d => d.encounters),
        backgroundColor: PALETTE.dewyBlue,
        borderColor: PALETTE.morningBreeze,
        borderWidth: 1,
        borderRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          title: { display: true, text: 'Number of Admissions' },
          grid: { color: '#F1F5F9' }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// 6. Hospital Comparison Chart
function renderHospitalChart(data) {
  const ctx = document.getElementById('chartHospital')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.slice(0, 8).map(d => d.hospital_name),
      datasets: [{
        label: 'Total Admissions',
        data: data.slice(0, 8).map(d => d.total_admissions),
        backgroundColor: PALETTE.sunwashed,
        borderColor: '#E6A23C',
        borderWidth: 1,
        borderRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          title: { display: true, text: 'Admissions' },
          ticks: { stepSize: 1 },
          grid: { color: '#F1F5F9' }
        },
        x: {
          ticks: { maxRotation: 45, minRotation: 25 },
          grid: { display: false }
        }
      }
    }
  });
}

// Fallback in case of local file:// cross-origin restriction
function renderFallbackCharts() {
  const fallbackConditions = [
    { medical_condition: 'Arthritis', records: 9218, total_billing: 235167617.95 },
    { medical_condition: 'Diabetes', records: 9216, total_billing: 236486971.03 },
    { medical_condition: 'Hypertension', records: 9151, total_billing: 233378490.11 },
    { medical_condition: 'Obesity', records: 9146, total_billing: 236006693.57 },
    { medical_condition: 'Cancer', records: 9140, total_billing: 229892231.55 },
    { medical_condition: 'Asthma', records: 9095, total_billing: 233136333.68 }
  ];
  renderConditionsChart(fallbackConditions);

  const fallbackAdmissions = [
    { admission_type: 'Elective', records: 18473, pct_records: 33.61 },
    { admission_type: 'Urgent', records: 18391, pct_records: 33.46 },
    { admission_type: 'Emergency', records: 18102, pct_records: 32.93 }
  ];
  renderAdmissionTypeChart(fallbackAdmissions);
}
