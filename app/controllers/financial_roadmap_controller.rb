class FinancialRoadmapController < ApplicationController
  before_action :set_milestone, only: %i[update destroy]

  def show
    @milestones = Current.family.roadmap_milestones.ordered
    @milestone = RoadmapMilestone.new(fecha_inicio: Date.current, fecha_objetivo: 1.year.from_now.to_date)
  end

  def create
    @milestone = Current.family.roadmap_milestones.build(milestone_params)

    if @milestone.save
      redirect_to financial_roadmap_path, notice: t("financial_roadmap.create.success")
    else
      @milestones = Current.family.roadmap_milestones.ordered
      render :show, status: :unprocessable_entity
    end
  end

  def update
    if @milestone.update(milestone_params)
      redirect_to financial_roadmap_path, notice: t("financial_roadmap.update.success")
    else
      @milestones = Current.family.roadmap_milestones.ordered
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @milestone.destroy!
    redirect_to financial_roadmap_path, notice: t("financial_roadmap.destroy.success")
  end

  private

    def set_milestone
      @milestone = Current.family.roadmap_milestones.find(params[:id])
    end

    def milestone_params
      params.require(:roadmap_milestone).permit(
        :nombre, :descripcion, :fecha_inicio, :fecha_objetivo,
        :monto_objetivo, :monto_actual, :estado, :color, :orden
      )
    end
end
