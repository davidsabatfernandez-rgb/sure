import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "amortSlider", "cuotaSlider",
    "amortLabel", "cuotaLabel",
    "mesesAhorrados", "interesesAhorrados", "nuevaFecha"
  ]
  static values = {
    url: String,
    accent: { type: String, default: "#D444F1" }
  }

  simulate() {
    const amort = parseFloat(this.amortSliderTarget.value) || 0
    const cuota = parseFloat(this.cuotaSliderTarget.value) || 0

    this.amortLabelTarget.textContent = new Intl.NumberFormat("es-ES", { style: "currency", currency: "EUR" }).format(amort)
    this.cuotaLabelTarget.textContent = "+" + new Intl.NumberFormat("es-ES", { style: "currency", currency: "EUR" }).format(cuota)

    if (amort === 0 && cuota === 0) {
      this.mesesAhorradosTarget.textContent = "-"
      this.interesesAhorradosTarget.textContent = "-"
      this.nuevaFechaTarget.textContent = "-"
      return
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken,
        "Accept": "application/json"
      },
      body: JSON.stringify({
        amortizacion_anticipada: amort,
        cuota_extra: cuota
      })
    })
    .then(r => r.json())
    .then(data => {
      this.mesesAhorradosTarget.textContent = data.meses_ahorrados + " meses"
      this.interesesAhorradosTarget.textContent = new Intl.NumberFormat("es-ES", { style: "currency", currency: "EUR" }).format(data.intereses_ahorrados)
      this.nuevaFechaTarget.textContent = data.nueva_fecha_liquidacion
    })
    .catch(() => {
      this.mesesAhorradosTarget.textContent = "Error"
    })
  }
}
