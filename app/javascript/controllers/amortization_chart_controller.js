import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static values = {
    schedule: Array,
    accent: { type: String, default: "#D444F1" }
  }

  connect() {
    this.draw()
    this.resizeObserver = new ResizeObserver(() => this.draw())
    this.resizeObserver.observe(this.element)
  }

  disconnect() {
    this.resizeObserver?.disconnect()
  }

  draw() {
    const container = this.element
    container.innerHTML = ""

    const schedule = this.scheduleValue
    if (!schedule || schedule.length === 0) {
      container.innerHTML = '<p style="text-align:center;color:#9E9E9E;padding:2rem">No hay datos de amortización</p>'
      return
    }

    const fmt = (n) => new Intl.NumberFormat("es-ES", { maximumFractionDigits: 0 }).format(n)
    const fmtK = (n) => {
      if (n >= 1000) return fmt(n / 1000) + "k"
      return fmt(n)
    }

    // Aggregate by year
    const years = []
    let cumulativeInterest = 0
    let cumulativeCapital = 0
    for (let i = 0; i < schedule.length; i += 12) {
      const slice = schedule.slice(i, i + 12)
      const yearInterest = slice.reduce((s, m) => s + m.intereses, 0)
      const yearCapital = slice.reduce((s, m) => s + m.capital, 0)
      cumulativeInterest += yearInterest
      cumulativeCapital += yearCapital
      years.push({
        year: Math.floor(i / 12) + 1,
        capital: yearCapital,
        intereses: yearInterest,
        pendiente: slice[slice.length - 1]?.pendiente || 0,
        cumulativeInterest,
        cumulativeCapital,
        interestPct: yearInterest / (yearInterest + yearCapital) * 100
      })
    }

    const margin = { top: 30, right: 50, bottom: 50, left: 65 }
    const width = container.clientWidth - margin.left - margin.right
    const height = 420 - margin.top - margin.bottom
    if (width <= 0) return

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    // Title
    svg.append("text")
      .attr("x", margin.left + width / 2)
      .attr("y", 18)
      .attr("text-anchor", "middle")
      .style("fill", "currentColor")
      .style("font-size", "13px")
      .style("font-weight", "600")
      .text("Capital vs Interés por año")

    const x = d3.scaleBand()
      .domain(years.map(d => d.year))
      .range([0, width])
      .padding(0.25)

    const maxStack = d3.max(years, d => d.capital + d.intereses)
    const y = d3.scaleLinear().domain([0, maxStack * 1.1]).range([height, 0])

    // Grid lines
    g.append("g")
      .attr("class", "grid")
      .call(d3.axisLeft(y).ticks(5).tickSize(-width).tickFormat(""))
      .selectAll("line")
      .style("stroke", "currentColor")
      .style("stroke-opacity", 0.08)
    g.selectAll(".grid .domain").remove()

    // X axis
    const tickInterval = Math.ceil(years.length / 15)
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).tickValues(years.filter((_, i) => i % tickInterval === 0).map(d => d.year)).tickFormat(d => `Año ${d}`))
      .selectAll("text")
      .style("fill", "currentColor")
      .style("font-size", "10px")
      .attr("transform", "rotate(-30)")
      .attr("text-anchor", "end")

    // Y axis
    g.append("g")
      .call(d3.axisLeft(y).ticks(5).tickFormat(d => fmtK(d) + " €"))
      .selectAll("text")
      .style("fill", "currentColor")
      .style("font-size", "10px")

    // Stacked bars - Interest (bottom)
    g.selectAll(".bar-int")
      .data(years)
      .join("rect")
      .attr("x", d => x(d.year))
      .attr("y", d => y(d.intereses))
      .attr("width", x.bandwidth())
      .attr("height", d => height - y(d.intereses))
      .attr("fill", "#EF4444")
      .attr("opacity", 0.6)
      .attr("rx", 3)

    // Stacked bars - Capital (top)
    g.selectAll(".bar-cap")
      .data(years)
      .join("rect")
      .attr("x", d => x(d.year))
      .attr("y", d => y(d.capital + d.intereses))
      .attr("width", x.bandwidth())
      .attr("height", d => y(d.intereses) - y(d.capital + d.intereses))
      .attr("fill", this.accentValue)
      .attr("opacity", 0.85)
      .attr("rx", 3)

    // Remaining balance line (secondary Y axis)
    const y2 = d3.scaleLinear()
      .domain([0, d3.max(years, d => d.pendiente) * 1.1])
      .range([height, 0])

    const line = d3.line()
      .x(d => x(d.year) + x.bandwidth() / 2)
      .y(d => y2(d.pendiente))
      .curve(d3.curveMonotoneX)

    g.append("path")
      .datum(years)
      .attr("d", line)
      .attr("fill", "none")
      .attr("stroke", "#3B82F6")
      .attr("stroke-width", 2.5)
      .attr("stroke-dasharray", "6,3")

    // Right Y axis for balance
    g.append("g")
      .attr("transform", `translate(${width},0)`)
      .call(d3.axisRight(y2).ticks(4).tickFormat(d => fmtK(d) + " €"))
      .selectAll("text")
      .style("fill", "#3B82F6")
      .style("font-size", "10px")

    // Dots on balance line
    g.selectAll(".dot-bal")
      .data(years.filter((_, i) => i % tickInterval === 0))
      .join("circle")
      .attr("cx", d => x(d.year) + x.bandwidth() / 2)
      .attr("cy", d => y2(d.pendiente))
      .attr("r", 4)
      .attr("fill", "#3B82F6")

    // Tooltip overlay
    const tooltip = d3.select(container)
      .append("div")
      .style("position", "absolute")
      .style("pointer-events", "none")
      .style("background", "rgba(0,0,0,0.85)")
      .style("color", "white")
      .style("padding", "8px 12px")
      .style("border-radius", "8px")
      .style("font-size", "12px")
      .style("display", "none")
      .style("z-index", "10")
      .style("line-height", "1.5")

    g.selectAll(".overlay-bar")
      .data(years)
      .join("rect")
      .attr("x", d => x(d.year))
      .attr("y", 0)
      .attr("width", x.bandwidth())
      .attr("height", height)
      .attr("fill", "transparent")
      .on("mouseenter", (e, d) => {
        tooltip.style("display", "block")
          .html(`<strong>Año ${d.year}</strong><br>Capital: ${fmt(d.capital)} €<br>Interés: ${fmt(d.intereses)} €<br>% interés: ${d.interestPct.toFixed(1)}%<br>─────<br>Pendiente: ${fmt(d.pendiente)} €<br>Acum. interés: ${fmt(d.cumulativeInterest)} €`)
      })
      .on("mousemove", (e) => {
        const rect = container.getBoundingClientRect()
        tooltip
          .style("left", (e.clientX - rect.left + 12) + "px")
          .style("top", (e.clientY - rect.top - 10) + "px")
      })
      .on("mouseleave", () => tooltip.style("display", "none"))

    // Legend
    const legend = svg.append("g").attr("transform", `translate(${margin.left + 10}, ${height + margin.top + 38})`)
    const items = [
      { color: this.accentValue, label: "Capital" },
      { color: "#EF4444", label: "Interés", opacity: 0.6 },
      { color: "#3B82F6", label: "Saldo pendiente", dash: true },
    ]
    items.forEach((item, i) => {
      const gItem = legend.append("g").attr("transform", `translate(${i * 140}, 0)`)
      if (item.dash) {
        gItem.append("line").attr("x1", 0).attr("y1", 6).attr("x2", 14).attr("y2", 6)
          .attr("stroke", item.color).attr("stroke-width", 2.5).attr("stroke-dasharray", "4,2")
      } else {
        gItem.append("rect").attr("width", 14).attr("height", 12).attr("fill", item.color)
          .attr("opacity", item.opacity || 0.85).attr("rx", 2)
      }
      gItem.append("text").attr("x", 18).attr("y", 10).text(item.label)
        .style("fill", "currentColor").style("font-size", "11px")
    })
  }
}
