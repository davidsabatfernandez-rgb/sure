import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="roadmap-suggestions"
export default class extends Controller {
  static targets = ["form", "nombre", "monto"];

  fill(event) {
    const { nombre, monto } = event.params;

    if (this.hasNombreTarget) {
      this.nombreTarget.value = nombre;
    }
    if (this.hasMontoTarget) {
      this.montoTarget.value = monto;
    }
  }
}
