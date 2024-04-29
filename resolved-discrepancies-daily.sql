DECLARE @nmDays int;
DECLARE @searchStartTime datetime;
DECLARE @searchStopTime datetime;

SET @nmDays = 1;		/* << specify before execution */

SET @searchStartTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE())-@nmDays,0);
SET @searchStopTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0);

SELECT [Starting] = DATENAME(dw,@searchStartTime)+', '+LEFT(CONVERT(varchar,@searchStartTime,113),17)
	,[Ending] = DATENAME(dw,DATEADD(s,-1,@searchStopTime))+', '+LEFT(CONVERT(varchar,DATEADD(s,-1,@searchStopTime),113),17);

WITH [Discrep_Res] AS
(
SELECT [Station_Id]
	,[Assoc_Event_Id]
	,[Resolution]
	,[Event_Dttm]
FROM CRX_DATA.dbo.AHI_CAB_EVENT
WHERE [Event_Type] = 'resolution'
	AND [Event_Dttm] BETWEEN @searchStartTime AND @searchStopTime
)
SELECT
	[HoursToResolve] = DATEDIFF(hh:mm,ce.[Event_Dttm],dr.[Event_Dttm])
	,[EventInstant] = CONVERT(datetime2(0),ce.[Event_Dttm])
	,[ResolutionInstant] = dr.[Event_Dttm]
	,[User] = LOWER(ce.[User_Name])+' ('+CONVERT(varchar,RTRIM(ce.[Site_User_Id]))+')'
	,[Witness] = COALESCE(LOWER(ce.[Witness_Name])+' ('+CONVERT(varchar,RTRIM(ce.[Witness_Site_User_Id]))+')','')
	,[Station] = ce.[Station_Id]
	,ce.[Event_Name]
	,[Med_Description] = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(dd.[Drug_Display_Name]),' ml',' mL'),'1 tab','tab'),' 1 ea',''),' (gm)',''),' gm',' g')
	,[Trans] =
        CASE
			WHEN ce.[Completed] = 0 THEN ''
			WHEN ce.[Event_Type_Num] IN (5,9) THEN ''
            WHEN ce.[Event_Type_Num] IN (1,2)  THEN CONVERT(varchar,CONVERT(float,dd.[Dose_Val]*ce.[Trans_Qty]))+' '+REPLACE(LOWER(dd.[Dose_Units]),'ml','mL')
            WHEN ce.[Event_Type_Num] = 3 THEN CONVERT(varchar,CONVERT(float,ce.[Trans_Qty]))+' '+REPLACE(LOWER(dd.[Dose_Units]),'ml','mL')
            WHEN ce.[Event_Type_Num] = 4 THEN CONVERT(varchar,CONVERT(float,ce.[Trans_Qty]))
            ELSE CONVERT(varchar,CONVERT(float,ce.[Trans_Qty]))
        END
    ,[Dose] =
		CASE
			WHEN ce.[Completed] = 0 THEN ''
			WHEN ce.[Event_Type_Num] = 1 AND ce.[Event_Subtype_Num] IN (2,3) THEN '' --don't show dose if override or inventory dispense
			WHEN ce.[Order_Dose_Max] IS NOT NULL AND ce.[Event_Type_Num] = 1
				THEN CONVERT(varchar,CONVERT(float,ce.[Order_Dose_Min]))+'-'+CONVERT(varchar,CONVERT(float,ce.[Order_Dose_Max]))+' '+REPLACE(LOWER(ce.[Order_Dose_Units]),'ml','mL')
			WHEN ce.[Order_Dose_Max] IS NULL AND ce.[Event_Type_Num] = 1
				THEN CONVERT(varchar,CONVERT(float,ce.[Order_Dose_Min]))+' '+REPLACE(LOWER(ce.[Order_Dose_Units]),'ml','mL')
			ELSE ''
		END
    ,[Begin_Qty] =
        CASE
            WHEN [Event_Type_Num] IN (3,9,10,16) THEN ''
            ELSE CONVERT(varchar,[Begin_Inventory_Level])
        END
    ,[End_Qty] =
        CASE
            WHEN [Event_Type_Num] IN (3,9,10,16) THEN ''
            ELSE CONVERT(varchar,[End_Inventory_Level])
        END
    ,[Exp_Qty] =
        CASE
            WHEN [Event_Type_Num] IN (3,9,10,16) THEN ''
            ELSE CONVERT(varchar,[Expected_Inventory_Level])
        END
    ,[Variance] =
        CASE
            WHEN ce.[Discrepancy_Status] IN ('O','R') THEN CONVERT(varchar,ce.[End_Inventory_Level]-ce.[Expected_Inventory_Level])
            ELSE ''
        END
	,[Discrepancy_Resolution] = COALESCE(REPLACE(dr.[Resolution],',',';'),'')
	,[Patient_Name] = COALESCE(LOWER(ce.[Pat_Name]),'')
	,[CSN] = COALESCE(CONVERT(varchar,ce.[Site_Patient_Id]),'')
    ,[Epic_Order#] = COALESCE([Primary_Ord_Num],'')
FROM [CRX_DATA].[dbo].[AHI_CAB_EVENT] AS ce
INNER JOIN [CRX_DATA].[dbo].[AHI_DRUG_DOSE] AS dd
    ON ce.[Drug_Dose_Id] = dd.[Drug_Dose_Id]
LEFT JOIN [CRX_DATA].[dbo].[AHI_ORDER] AS ord
    ON ce.[Pat_Id] = ord.[Pat_Id] AND ce.[Pat_Ord_Num] = ord.[Pat_Ord_Num]
LEFT JOIN [Discrep_Res] AS dr
	ON ce.[Station_Id] = dr.[Station_Id] AND ce.[Event_Id] = dr.[Assoc_Event_Id]
WHERE ce.[Site_Delivery_Site_ID] = 'S'
	AND ce.[Station_Id] NOT IN ('GIC1','GIC2','GIC4','GICG','GICP','OPV','SRERP')
	AND ce.[Dea_Admin_Code] != 0
	AND ce.[Event_Dttm] BETWEEN @searchStartTime AND @searchStopTime
	AND ce.[Discrepancy_Status] = 'r'
ORDER BY [Station],[Med_Description],[Event_Instant];
