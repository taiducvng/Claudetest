@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Request Status Value Help'
@ObjectModel.dataCategory: #VALUE_HELP
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_REQ_STATUS_VH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZRAP_D_REQ_STATUS' )
{
      @ObjectModel.text.element: ['StatusText']
  key cast( value_low as abap.char( 2 ) ) as Status,
      @Semantics.text: true
      cast( text as abap.char( 60 ) )     as StatusText,
      // 0 neutral, 1 red, 2 orange, 3 green, 5 blue
      cast( case value_low
              when '02' then 5
              when '03' then 3
              when '04' then 1
              when '05' then 2
              when '06' then 5
              when '07' then 2
              when '08' then 2
              when '09' then 3
              when '10' then 1
              else 0
            end as abap.int1 )            as Criticality
}
where
  language = $session.system_language
