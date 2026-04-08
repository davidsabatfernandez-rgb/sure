import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

export default class extends Controller {
  static targets = ["canvas"]
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
    if (!schedule || schedule.length === 0) return

    // Aggregate by year
    const years = []
    for (let i = 0; i < schedule.length; i += 12) {
      const yearSlice = schedule.slice(i, i + 12)
      years.push({
        year: Math.floor(i / 12) + 1,
        capital: yearSlice.reduce((s, m) => s + m.capital, 0),
        intereses: yearSlice.reduce((s, m) => s + m.intereses, 0)
      })
    }

    const margin = { top: 20, right: 20, bottom: 40, left: 60 }
    const width = container.clientWidth - margin.left - margin.right
    const height = 360 - margin.top - margin.bottom

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    const x = d3.scaleBand()
      .domain(years.map(d => d.year))
      .range([0, width])
      .padding(0.3)

    const maxY = d3.max(years, d => d.capital + d.intereses)
    const y = d3.scaleLinear()
      .domain([0, maxY * 1.1])
      .range([height, 0])

    // Axes
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).tickValues(years.filter((_, i) => i % Math.ceil(years.length / 10) === 0).map(d => d.year)))
      .selectAll("text")
      .style("fill", "currentColor")
      .style("font-size", "11px")

    svg.append("g")
      .call(d3.axisLeft(y).ticks(5).tickFormat(d => new Intl.NumberFormat("es-ES", { notation: "compact" }).format(d)))
      .selectAll("text")
      .style("fill", "currentColor")
      .style("font-size", "11px")

    // Stacked bars - Interest (bottom, gray)
    svg.selectAll(".bar-interest")
      .data(years)
      .join("rect")
      .attr("class", "bar-interest")
      .attr("x", d => x(d.year))
      .attr("y", d => y(d.intereses))
      .attr("width", x.bandwidth())
      .attr("height", d => height - y(d.intereses))
      .attr("fill", "#9E9E9E")
      .attr("rx", 2)

    // Stacked bars - Capital (top, accent)
    svg.selectAll(".bar-capital")
      .data(years)
      .join("rect")
      .attr("class", "bar-capital")
      .attr("x", d => x(d.year))
      .attr("y", d => y(d.capital + d.intereses))
      .attr("width", x.bandwidth())
      .attr("height", d => y(d.intereses) - y(d.capital + d.intereses))
      .attr("fill", this.accentValue)
      .attr("rx", 2)

    // Legend
    const legend = svg.append("g").attr("transform", `translate(${width - 160}, -10)`)
    legend.append("rect").attr("width", 12).attr("height", 12).attr("fill", this.accentValue).attr("rx", 2)
    legend.append("text").attr("x", 16).attr("y", 10).text("Capital").style("fill", "currentColor").style("font-size", "11px")
    legend.append("rect").attr("x", 80).attr("width", 12).attr("height", 12).attr("fill", "#9E9E9E").attr("rx", 2)
    legend.append("text").attr("x", 96).attr("y", 10).text("Intereses").style("fill", "currentColor").style("font-size", "11px")

    // X label
    svg.append("text")
      .attr("x", width / 2)
      .attr("y", height + 35)
      .attr("text-anchor", "middle")
      .style("fill", "currentColor")
      .style("font-size", "12px")
      .text("Años")
  }
}
