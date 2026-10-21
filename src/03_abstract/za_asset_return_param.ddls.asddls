@EndUserText.label: 'Return Asset - Parameter'
define abstract entity ZA_ASSET_RETURN_PARAM
{
  @EndUserText.label: 'Return Date'
  ReturnDate      : abap.dats;
  @EndUserText.label: 'Return Condition'
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_RETURN_CONDITION_VH', element: 'ConditionCode' } }]
  ReturnCondition : abap.char(2);
  @EndUserText.label: 'Return Note'
  ReturnNote      : abap.char(255);
}
