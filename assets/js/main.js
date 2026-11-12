/**
 * Healthcare SQL Analytics Portfolio — Application Logic
 * Role: Data Analyst / Frontend Engineer
 * Features: Verified Chart.js Visualizations, Resilient Fetch, Tab Switching, Copy Snippets
 */

document.addEventListener('DOMContentLoaded', () => {
  initMobileNav();
  initCaseStudyTabs();
  initCodeCopy();
  initCharts();
});

// 1. Accessible Mobile Navigation
function initMobileNav() {
  const toggle = document.querySelector('.mobile-toggle');
  const navLinks = document.querySelector('.nav-links');
  if (!toggle || !navLinks) return;

  toggle.addEventListener('click', () => {
    const isOpen = navLinks.classList.toggle('open');
    toggle.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
  });

  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      navLinks.classList.remove('open');
      toggle.setAttribute('aria-expanded', 'false');
    });
  });
}

// 2. Case Study Tabs (Accessible ARIA state)
function initCaseStudyTabs() {
  const tabs = document.querySelectorAll('.case-tab-btn');
  const panels = document.querySelectorAll('.case-panel');

  tabs.forEach(tab => {
    tab.addEventListener('click', () => {
      const targetId = tab.getAttribute('data-target');

      tabs.forEach(t => {
        t.classList.remove('active');
        t.setAttribute('aria-selected', 'false');
      });

      panels.forEach(p => {
        p.classList.remove('active');
        p.hidden = true;
      });

      tab.classList.add('active');
      tab.setAttribute('aria-selected', 'true');

      const targetPanel = document.getElementById(targetId);
      if (targetPanel) {
        targetPanel.classList.add('active');
        targetPanel.hidden = false;
      }
    });
  });
}

// 3. SQL Copy to Clipboard
function initCodeCopy() {
  document.querySelectorAll('.btn-copy').forEach(btn => {
    btn.addEventListener('click', () => {
      const codeBlock = btn.closest('.code-box')?.querySelector('code');
      if (!codeBlock) return;

      navigator.clipboard.writeText(codeBlock.innerText).then(() => {
        const origText = btn.innerText;
        btn.innerText = 'Copied!';
        btn.style.backgroundColor = '#15803D';
        btn.style.color = '#FFFFFF';
        setTimeout(() => {
          btn.innerText = origText;
          btn.style.backgroundColor = '';
          btn.style.color = '';
        }, 2000);
      }).catch(err => {
        console.error('Clipboard copy failed:', err);
      });
    });
  });
}

// 4. Professional Visualizations with Chart.js
const CHART_COLORS = {
  bluePrimary: '#2563EB',
  blueLight: '#93C5FD',
  blueSubtle: 'rgba(37, 99, 235, 0.08)',
  navyDark: '#1E293B',
  amberAccent: '#D97706',
  slateMuted: '#64748B',
  slateLight: '#E2E8F0',
  tealAccent: '#0D9488',
  redUrgent: '#DC2626'
};

// Global Chart.js defaults
if (window.Chart) {
  Chart.defaults.font.family = "'Inter', -apple-system, BlinkMacSystemFont, sans-serif";
  Chart.defaults.color = '#64748B';
  Chart.defaults.plugins.tooltip.backgroundColor = '#0F172A';
  Chart.defaults.plugins.tooltip.titleColor = '#F8FAFC';
  Chart.defaults.plugins.tooltip.bodyColor = '#E2E8F0';
  Chart.defaults.plugins.tooltip.padding = 10;
  Chart.defaults.plugins.tooltip.cornerRadius = 6;
  Chart.defaults.plugins.legend.labels.usePointStyle = true;
}

async function fetchJsonData(endpoint) {
  const resp = await fetch(endpoint);
  if (!resp.ok) {
    throw new Error(`HTTP ${resp.status} fetching ${endpoint}`);
  }
  return await resp.json();
}

function showChartError(canvasId, message) {
  const canvas = document.getElementById(canvasId);
  if (!canvas) return;
  const container = canvas.closest('.chart-container');
  if (container) {
    container.innerHTML = `
      <div class="chart-error-banner" role="status">
        <div>
          <strong style="color: #0F172A; display: block; margin-bottom: 0.25rem;">Data Visualization Unavailable</strong>
          <p style="margin: 0; font-size: 0.8rem; color: #64748B;">${message}</p>
        </div>
      </div>
    `;
  }
}

async function initCharts() {
  // Chart 1: Medical Conditions
  try {
    const data = await fetchJsonData('assets/data/conditions.json');
    renderConditionsChart(data);
  } catch (err) {
    console.error('Conditions data fetch failed:', err);
    showChartError('chartConditions', 'Failed to load assets/data/conditions.json.');
  }

  // Chart 2: Cost Quartiles & Outliers
  try {
    const data = await fetchJsonData('assets/data/cost_quartiles.json');
    renderCostQuartilesChart(data);
  } catch (err) {
    console.error('Cost Quartiles data fetch failed:', err);
    showChartError('chartCostQuartiles', 'Failed to load assets/data/cost_quartiles.json.');
  }

  // Chart 3: Monthly Trends Timeline
  try {
    const data = await fetchJsonData('assets/data/monthly_trends.json');
    renderMonthlyTrendsChart(data);
  } catch (err) {
    console.error('Monthly trends data fetch failed:', err);
    showChartError('chartMonthlyTrends', 'Failed to load assets/data/monthly_trends.json.');
  }

  // Chart 4: Insurance Carrier Breakdown
  try {
    const data = await fetchJsonData('assets/data/insurance.json');
    renderInsuranceChart(data);
  } catch (err) {
    console.error('Insurance data fetch failed:', err);
    showChartError('chartInsurance', 'Failed to load assets/data/insurance.json.');
  }

  // Chart 5: Length of Stay Distribution
  try {
    const data = await fetchJsonData('assets/data/los_distribution.json');
    renderLosChart(data);
  } catch (err) {
    console.error('LOS distribution data fetch failed:', err);
    showChartError('chartLos', 'Failed to load assets/data/los_distribution.json.');
  }

  // Chart 6: Admission Urgency Mix
  try {
    const data = await fetchJsonData('assets/data/admission_types.json');
    renderAdmissionTypeChart(data);
  } catch (err) {
    console.error('Admission type data fetch failed:', err);
    showChartError('chartAdmissionType', 'Failed to load assets/data/admission_types.json.');
  }
}

// Chart 1: Conditions Dual-Axis Bar & Line
function renderConditionsChart(data) {
  const ctx = document.getElementById('chartConditions')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.medical_condition),
      datasets: [
        {
          label: 'Inpatient Encounters',
          data: data.map(d => d.records),
          backgroundColor: CHART_COLORS.blueLight,
          borderColor: CHART_COLORS.bluePrimary,
          borderWidth: 1,
          borderRadius: 4,
          yAxisID: 'y'
        },
        {
          label: 'Total Billed Charges ($M)',
          data: data.map(d => (d.total_billing / 1e6).toFixed(2)),
          type: 'line',
          borderColor: CHART_COLORS.amberAccent,
          backgroundColor: CHART_COLORS.amberAccent,
          pointBackgroundColor: CHART_COLORS.amberAccent,
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
          grid: { color: CHART_COLORS.slateLight }
        },
        y1: {
          position: 'right',
          title: { display: true, text: 'Billed Charges ($M USD)' },
          grid: { drawOnChartArea: false }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// Chart 2: Cost Quartiles & Revenue Dispersion
function renderCostQuartilesChart(data) {
  const ctx = document.getElementById('chartCostQuartiles')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.billing_quartile),
      datasets: [
        {
          label: 'Total Billed Charges ($M)',
          data: data.map(d => (d.total_billing / 1e6).toFixed(2)),
          backgroundColor: [
            CHART_COLORS.slateLight,
            CHART_COLORS.blueLight,
            CHART_COLORS.bluePrimary,
            CHART_COLORS.navyDark
          ],
          borderRadius: 4,
          yAxisID: 'y'
        },
        {
          label: 'Average Charge ($)',
          data: data.map(d => d.avg_billing),
          type: 'line',
          borderColor: CHART_COLORS.amberAccent,
          backgroundColor: CHART_COLORS.amberAccent,
          pointBackgroundColor: CHART_COLORS.amberAccent,
          borderWidth: 2,
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
          title: { display: true, text: 'Cumulative Billing ($M)' },
          grid: { color: CHART_COLORS.slateLight }
        },
        y1: {
          position: 'right',
          title: { display: true, text: 'Average Charge ($)' },
          grid: { drawOnChartArea: false }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// Chart 3: Longitudinal Monthly Admissions Timeline
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
          borderColor: CHART_COLORS.bluePrimary,
          backgroundColor: CHART_COLORS.blueSubtle,
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
          grid: { color: CHART_COLORS.slateLight }
        },
        x: {
          ticks: { maxTicksLimit: 12 },
          grid: { display: false }
        }
      }
    }
  });
}

// Chart 4: Insurance Carrier Breakdown
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
        backgroundColor: CHART_COLORS.bluePrimary,
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
          grid: { color: CHART_COLORS.slateLight }
        },
        y: { grid: { display: false } }
      }
    }
  });
}

// Chart 5: Length of Stay Distribution
function renderLosChart(data) {
  const ctx = document.getElementById('chartLos')?.getContext('2d');
  if (!ctx || !data) return;

  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: data.map(d => d.los_tier),
      datasets: [
        {
          label: 'Encounter Count',
          data: data.map(d => d.encounters),
          backgroundColor: CHART_COLORS.blueLight,
          borderRadius: 4,
          yAxisID: 'y'
        },
        {
          label: 'Average Charge ($)',
          data: data.map(d => d.avg_billing),
          type: 'line',
          borderColor: CHART_COLORS.amberAccent,
          backgroundColor: CHART_COLORS.amberAccent,
          pointBackgroundColor: CHART_COLORS.amberAccent,
          borderWidth: 2,
          yAxisID: 'y1'
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        y: {
          title: { display: true, text: 'Admissions' },
          grid: { color: CHART_COLORS.slateLight }
        },
        y1: {
          position: 'right',
          title: { display: true, text: 'Avg Charge ($)' },
          min: 20000,
          max: 30000,
          grid: { drawOnChartArea: false }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// Chart 6: Admission Urgency Mix (Donut)
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
          CHART_COLORS.bluePrimary,
          CHART_COLORS.amberAccent,
          CHART_COLORS.redUrgent
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
