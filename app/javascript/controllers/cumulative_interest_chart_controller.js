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

  disconnect() { this.resizeObserver?.disconnect() }

  draw() {
    const container = this.element
    container.innerHTML = ""
    const schedule = this.scheduleValue
    if (!schedule || schedule.length === 0) return

    const fmt = (n) => new Intl.NumberFormat("es-ES", { maximumFractionDigits: 0 }).format(n)
    const fmtK = (n) => n >= 1000 ? fmt(n / 1000) + "k" : fmt(n)

    // Build cumulative data by year
    const years = []
    let cumInt = 0, cumCap = 0
    for (let i = 0; i < schedule.length; i += 12) {
      const slice = schedule.slice(i, i + 12)
      cumInt += slice.reduce((s, m) => s + m.intereses, 0)
      cumCap += slice.reduce((s, m) => s + m.capital, 0)
      years.push({ year: Math.floor(i / 12) + 1, cumInt, cumCap, total: cumInt + cumCap })
    }

    const margin = { top: 30, right: 20, bottom: 45, left: 65 }
    const width = container.clientWidth - margin.left - margin.right
    const height = 320 - margin.top - margin.bottom
    if (width <= 0) return

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)

    svg.append("text")
      .attr("x", margin.left + width / 2).attr("y", 18)
      .attr("text-anchor", "middle")
      .style("fill", "currentColor").style("font-size", "13px").style("font-weight", "600")
      .text("Acumulado: lo que pagas en capital vs interés")

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleLinear().domain([1, years.length]).range([0, width])
    const maxY = d3.max(years, d => d.total)
    const y = d3.scaleLinear().domain([0, maxY * 1.05]).range([height, 0])

    // Grid
    g.append("g").call(d3.axisLeft(y).ticks(5).tickSize(-width).tickFormat(""))
      .selectAll("line").style("stroke", "currentColor").style("stroke-opacity", 0.08)
    g.selectAll(".domain").remove()

    // Areas
    const areaCap = d3.area().x(d => x(d.year)).y0(height).y1(d => y(d.cumCap)).curve(d3.curveMonotoneX)
    const areaInt = d3.area().x(d => x(d.year)).y0(d => y(d.cumCap)).y1(d => y(d.total)).curve(d3.curveMonotoneX)

    g.append("path").datum(years).attr("d", areaCap)
      .attr("fill", this.accentValue).attr("opacity", 0.3)
    g.append("path").datum(years).attr("d", areaInt)
      .attr("fill", "#EF4444").attr("opacity", 0.25)

    // Lines
    const lineCap = d3.line().x(d => x(d.year)).y(d => y(d.cumCap)).curve(d3.curveMonotoneX)
    const lineTotal = d3.line().x(d => x(d.year)).y(d => y(d.total)).curve(d3.curveMonotoneX)

    g.append("path").datum(years).attr("d", lineCap)
      .attr("fill", "none").attr("stroke", this.accentValue).attr("stroke-width", 2.5)
    g.append("path").datum(years).attr("d", lineTotal)
      .attr("fill", "none").attr("stroke", "#EF4444").attr("stroke-width", 2)

    // Axes
    g.append("g").attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).ticks(Math.min(years.length, 10)).tickFormat(d => `Año ${d}`))
      .selectAll("text").style("fill", "currentColor").style("font-size", "10px")
    g.append("g").call(d3.axisLeft(y).ticks(5).tickFormat(d => fmtK(d) + " €"))
      .selectAll("text").style("fill", "currentColor").style("font-size", "10px")

    // End labels
    const last = years[years.length - 1]
    g.append("text").attr("x", width + 4).attr("y", y(last.cumCap) + 4)
      .style("fill", this.accentValue).style("font-size", "11px").style("font-weight", "600")
      .text(fmtK(last.cumCap) + " €")
    g.append("text").attr("x", width + 4).attr("y", y(last.total) + 4)
      .style("fill", "#EF4444").style("font-size", "11px").style("font-weight", "600")
      .text(fmtK(last.cumInt) + " € int.")

    // Legend
    const legend = svg.append("g").attr("transform", `translate(${margin.left + 10}, ${height + margin.top + 35})`)
    const items = [
      { color: this.accentValue, label: "Capital acumulado" },
      { color: "#EF4444", label: "Interés acumulado" },
    ]
    items.forEach((item, i) => {
      const gi = legend.append("g").attr("transform", `translate(${i * 170}, 0)`)
      gi.append("rect").attr("width", 12).attr("height", 12).attr("fill", item.color).attr("opacity", 0.7).attr("rx", 2)
      gi.append("text").attr("x", 16).attr("y", 10).text(item.label).style("fill", "currentColor").style("font-size", "11px")
    })
  }
}
