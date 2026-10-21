@EndUserText.label: 'Report Lost - Parameter'
define abstract entity ZA_ASSET_LOST_PARAM
{
  @EndUserText.label: 'Lost Date'
  LostDate : abap.dats;
  @EndUserText.label: 'Note'
  Note     : abap.char(255);
}
