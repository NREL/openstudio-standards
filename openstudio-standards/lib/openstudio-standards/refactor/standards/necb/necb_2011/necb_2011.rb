class NECB_2011_Model < StandardsModel
  @@template = 'NECB 2011'
  register_standard (@@template)
  attr_reader :instvartemplate

  def initialize
    super()
    @instvartemplate = @@template
  end
end
