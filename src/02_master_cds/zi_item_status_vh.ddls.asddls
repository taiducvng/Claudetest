@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Item Status Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITEM_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZRAP_D_ITEM_STATUS' )
{
      @ObjectModel.text.element: ['ItemStatusText']
  key cast( value_low as abap.char( 2 ) ) as ItemStatus,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )     as ItemStatusText
}
where
  language = $session.system_language
