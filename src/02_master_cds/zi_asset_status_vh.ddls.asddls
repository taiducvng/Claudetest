@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Asset Status Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ASSET_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZRAP_D_ASSET_STATUS' )
{
      @ObjectModel.text.element: ['AssetStatusText']
  key cast( value_low as abap.char( 2 ) ) as AssetStatus,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )     as AssetStatusText
}
where
  language = $session.system_language
