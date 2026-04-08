import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

// Connects to data-controller="goal-calculator"
export default class extends Controller {
  static targets = [
    "objetivo",
    "ahorro",
    "interes",
    "inicial",
    "scenarioSelect",
    "resultsPanel",
    "emptyState",
    "fechaResult",
    "mesesResult",
    "interesResult",
    "totalResult",
    "chart",
  ];

  connect() {
    this.calculate();
  }

  loadScenario() {
    const value = this.scenarioSelectTarget.value;
    if (!value) return;

    const [objetivo, ahorro, interes, inicial] = value.split("|").map(Number);
    this.objetivoTarget.value = objetivo;
    this.ahorroTarget.value = ahorro;
    this.interesTarget.value = interes;
    this.inicialTarget.value = inicial;

    this.calculate();
  }

  calculate() {
    const objetivo = parseFloat(this.objetivoTarget.value) || 0;
    const ahorroMensual = parseFloat(this.ahorroTarget.value) || 0;
    const interesAnual = parseFloat(this.interesTarget.value) || 0;
    const inicial = parseFloat(this.inicialTarget.value) || 0;

    if (objetivo <= 0 || ahorroMensual <= 0) {
      this.resultsPanelTarget.classList.add("hidden");
      this.emptyStateTarget.classList.remove("hidden");
      return;
    }

    this.resultsPanelTarget.classList.remove("hidden");
    this.emptyStateTarget.classList.add("hidden");

    const interesMensual = interesAnual / 100 / 12;
    const dataPoints = [];
    let acumulado = inicial;
    let totalIntereses = 0;
    let meses = 0;
    const maxMeses = 1200; // 100 years cap

    while (acumulado < objetivo && meses < maxMeses) {
      const interesDelMes = acumulado * interesMensual;
      totalIntereses += interesDelMes;
      acumulado += ahorroMensual + interesDelMes;
      meses++;

      dataPoints.push({
        mes: meses,
        acumulado: Math.min(acumulado, objetivo),
        aportaciones: inicial + ahorroMensual * meses,
        intereses: totalIntereses,
      });
    }

    // Calculate target date
    const fechaObjetivo = new Date();
    fechaObjetivo.setMonth(fechaObjetivo.getMonth() + meses);

    const fechaFormateada = fechaObjetivo.toLocaleDateString("es-ES", {
      year: "numeric",
      month: "long",
    });

    // Update results
    this.fechaResultTarget.textContent = fechaFormateada;
    this.mesesResultTarget.textContent = `${meses} meses (${(meses / 12).toFixed(1)} a\u00F1os)`;
    this.interesResultTarget.textContent = `+${this.#formatCurrency(totalIntereses)}`;
    this.totalResultTarget.textContent = this.#formatCurrency(
      Math.min(acumulado, objetivo)
    );

    // Draw chart
    this.#drawChart(dataPoints, objetivo);
  }

  #formatCurrency(value) {
    return new Intl.NumberFormat("es-ES", {
      style: "currency",
      currency: "EUR",
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  }

  #drawChart(data, objetivo) {
    const container = this.chartTarget;
    container.innerHTML = "";

    if (data.length === 0) return;

    const margin = { top: 10, right: 10, bottom: 30, left: 50 };
    const width = container.clientWidth - margin.left - margin.right;
    const height = container.clientHeight - margin.top - margin.bottom;

    const svg = d3
      .select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3
      .scaleLinear()
      .domain([0, d3.max(data, (d) => d.mes)])
      .range([0, width]);

    const y = d3
      .scaleLinear()
      .domain([0, objetivo * 1.05])
      .range([height, 0]);

    // Grid lines
    svg
      .append("g")
      .attr("class", "grid")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).ticks(6).tickSize(-height).tickFormat(""))
      .selectAll("line")
      .attr("stroke", "var(--color-border-primary)")
      .attr("stroke-opacity", 0.3);

    svg
      .append("g")
      .attr("class", "grid")
      .call(d3.axisLeft(y).ticks(5).tickSize(-width).tickFormat(""))
      .selectAll("line")
      .attr("stroke", "var(--color-border-primary)")
      .attr("stroke-opacity", 0.3);

    // Remove domain lines from grids
    svg.selectAll(".grid .domain").remove();

    // Aportaciones area (contributions without interest)
    const areaAportaciones = d3
      .area()
      .x((d) => x(d.mes))
      .y0(height)
      .y1((d) => y(d.aportaciones))
      .curve(d3.curveMonotoneX);

    svg
      .append("path")
      .datum(data)
      .attr("fill", "#3B82F6")
      .attr("fill-opacity", 0.2)
      .attr("d", areaAportaciones);

    // Acumulado area (total with interest)
    const areaAcumulado = d3
      .area()
      .x((d) => x(d.mes))
      .y0((d) => y(d.aportaciones))
      .y1((d) => y(d.acumulado))
      .curve(d3.curveMonotoneX);

    svg
      .append("path")
      .datum(data)
      .attr("fill", "#22C55E")
      .attr("fill-opacity", 0.2)
      .attr("d", areaAcumulado);

    // Acumulado line
    const lineAcumulado = d3
      .line()
      .x((d) => x(d.mes))
      .y((d) => y(d.acumulado))
      .curve(d3.curveMonotoneX);

    svg
      .append("path")
      .datum(data)
      .attr("fill", "none")
      .attr("stroke", "#22C55E")
      .attr("stroke-width", 2)
      .attr("d", lineAcumulado);

    // Objetivo line
    svg
      .append("line")
      .attr("x1", 0)
      .attr("x2", width)
      .attr("y1", y(objetivo))
      .attr("y2", y(objetivo))
      .attr("stroke", "#EF4444")
      .attr("stroke-width", 1.5)
      .attr("stroke-dasharray", "6,3");

    svg
      .append("text")
      .attr("x", width - 4)
      .attr("y", y(objetivo) - 6)
      .attr("text-anchor", "end")
      .attr("fill", "#EF4444")
      .attr("font-size", "11px")
      .text("Objetivo");

    // Axes
    svg
      .append("g")
      .attr("transform", `translate(0,${height})`)
      .call(
        d3
          .axisBottom(x)
          .ticks(6)
          .tickFormat((d) => `${d}m`)
      )
      .selectAll("text")
      .attr("fill", "var(--color-text-secondary)")
      .attr("font-size", "10px");

    svg
      .append("g")
      .call(
        d3
          .axisLeft(y)
          .ticks(5)
          .tickFormat((d) => `${(d / 1000).toFixed(0)}k`)
      )
      .selectAll("text")
      .attr("fill", "var(--color-text-secondary)")
      .attr("font-size", "10px");

    // Style axis lines
    svg.selectAll(".domain").attr("stroke", "var(--color-border-primary)");
    svg.selectAll(".tick line").attr("stroke", "var(--color-border-primary)");
  }
}
