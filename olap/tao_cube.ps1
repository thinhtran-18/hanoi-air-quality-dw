$ErrorActionPreference='Stop'
Add-Type -Path 'C:\Program Files\Microsoft SQL Server\170\DTS\Binn\Microsoft.AnalysisServices.dll'
Add-Type -AssemblyName System.Data
$server=[Microsoft.AnalysisServices.Server]::new()
$server.Connect('localhost')
$db=$server.Databases.FindByName('HanoiAirOLAP')
if ($db -and ($db.Cubes.Count -gt 0 -or $db.Dimensions.Count -gt 0)) { throw 'HanoiAirOLAP contains cube or dimensions; refusing to overwrite.' }
if (-not $db) {$db=$server.Databases.Add('HanoiAirOLAP','HanoiAirOLAP'); $db.Update()}
$ds=$db.DataSources.FindByName('Warehouse'); if (-not $ds) {$ds=$db.DataSources.Add('Warehouse','Warehouse')}
$ds.ConnectionString='Provider=MSOLEDBSQL19.1;Data Source=localhost;Initial Catalog=hanoi_air_dw;Integrated Security=SSPI;Trust Server Certificate=True;'
$ds.ImpersonationInfo=[Microsoft.AnalysisServices.ImpersonationInfo]::new([Microsoft.AnalysisServices.ImpersonationMode]::ImpersonateServiceAccount)
$ds.Update()
$dsv=$db.DataSourceViews.FindByName('Warehouse'); if (-not $dsv) {$dsv=$db.DataSourceViews.Add('Warehouse','Warehouse')}
$dsv.DataSourceID=$ds.ID
$set=[System.Data.DataSet]::new('Warehouse')
$conn=[System.Data.SqlClient.SqlConnection]::new('Server=localhost;Database=hanoi_air_dw;Integrated Security=True;TrustServerCertificate=True')
$conn.Open()
foreach($name in @('FactAirQuality','DimDate','DimTime','DimStation','DimPollutant','DimSensor')) {
 $adapter=[System.Data.SqlClient.SqlDataAdapter]::new("SELECT * FROM dbo.[$name] WHERE 1=0",$conn)
 [void]$adapter.FillSchema($set,[System.Data.SchemaType]::Mapped,$name)
 $t=$set.Tables[$name]
 $t.ExtendedProperties.Add('TableType','Table'); $t.ExtendedProperties.Add('DbSchemaName','dbo'); $t.ExtendedProperties.Add('DbTableName',$name); $t.ExtendedProperties.Add('FriendlyName',$name)
}
$conn.Close()
$dsv.Schema=$set
$dsv.Update()
function Item($table,$column) {
 $type=[Microsoft.AnalysisServices.OleDbTypeConverter]::GetRestrictedOleDbType($set.Tables[$table].Columns[$column].DataType)
 return [Microsoft.AnalysisServices.DataItem]::new($table,$column,$type)
}
$defs=@(
 @{Name='Date';Table='DimDate';Key='DateKey';Label='FullDate';Attrs=@('YearNumber','QuarterNumber','MonthNumber')},
 @{Name='Time';Table='DimTime';Key='TimeKey';Label='HourNumber';Attrs=@('HourNumber')},
 @{Name='Station';Table='DimStation';Key='StationKey';Label='StationName';Attrs=@('DistrictName')},
 @{Name='Pollutant';Table='DimPollutant';Key='PollutantKey';Label='PollutantCode';Attrs=@('Unit')},
 @{Name='Sensor';Table='DimSensor';Key='SensorKey';Label='SensorId';Attrs=@('SensorId','SensorDescription')}
)
foreach($v in $defs){
 $dim=$db.Dimensions.Add($v.Name,$v.Name); $dim.Source=[Microsoft.AnalysisServices.DataSourceViewBinding]::new($dsv.ID)
 $attr=$dim.Attributes.Add($v.Name,$v.Name); $attr.Usage=[Microsoft.AnalysisServices.AttributeUsage]::Key
 [void]$attr.KeyColumns.Add((Item $v.Table $v.Key)); if ($set.Tables[$v.Table].Columns[$v.Label].DataType -eq [string]) {$attr.NameColumn=Item $v.Table $v.Label}
 foreach($col in $v.Attrs){$a=$dim.Attributes.Add($col,$col); [void]$a.KeyColumns.Add((Item $v.Table $col)); if ($set.Tables[$v.Table].Columns[$col].DataType -eq [string]) {$a.NameColumn=Item $v.Table $col}}
 $dim.Update()
}
$cube=$db.Cubes.Add('Air Quality','Air Quality'); $cube.Source=[Microsoft.AnalysisServices.DataSourceViewBinding]::new($dsv.ID)
foreach($v in $defs){[void]$cube.Dimensions.Add($v.Name)}
$mg=$cube.MeasureGroups.Add('Observations','Observations')
$count=$mg.Measures.Add('Observation Count','Observation Count'); $count.AggregateFunction=[Microsoft.AnalysisServices.AggregationFunction]::Count; $count.Source=Item 'FactAirQuality' 'AirQualityKey'; $count.FormatString='#,##0'
$sum=$mg.Measures.Add('Value Sum Internal','Value Sum Internal'); $sum.AggregateFunction=[Microsoft.AnalysisServices.AggregationFunction]::Sum; $sum.Source=Item 'FactAirQuality' 'Value'; $sum.Visible=$false
foreach($v in $defs){$cd=$cube.Dimensions.GetByName($v.Name); $md=[Microsoft.AnalysisServices.RegularMeasureGroupDimension]::new($cd.ID); [void]$mg.Dimensions.Add($md); $ma=$md.Attributes.Add($v.Name); $ma.Type=[Microsoft.AnalysisServices.MeasureGroupAttributeType]::Granularity; [void]$ma.KeyColumns.Add((Item 'FactAirQuality' $v.Key))}
$part=$mg.Partitions.Add('Valid Observations','Valid Observations'); $part.Source=[Microsoft.AnalysisServices.QueryBinding]::new($ds.ID,'SELECT * FROM dbo.FactAirQuality WHERE IsValid = 1')
$script=$cube.MdxScripts.Add('Main','Main'); [void]$script.Commands.Add([Microsoft.AnalysisServices.Command]::new('CALCULATE; CREATE MEMBER CURRENTCUBE.[Measures].[Mean Concentration] AS IIF([Pollutant].[Pollutant].CurrentMember IS [Pollutant].[Pollutant].[All], NULL, IIF([Measures].[Observation Count]=0, NULL, [Measures].[Value Sum Internal]/[Measures].[Observation Count])), FORMAT_STRING = "0.00", VISIBLE = 1;'))
$cube.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
$db.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)
$server.Disconnect()
