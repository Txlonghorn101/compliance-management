module CyclesHelper

  def generate_default_title_for_cycle(program=nil)
    default_title = (program.nil? ? "" : program.title) + " Audit"
    duplicates = Cycle.where("title LIKE %?%", default_title).count
    default_title +=  count > 1 ? count.to_s : "" 
    return "#{Date.today.year} - " + default_title
  end
end