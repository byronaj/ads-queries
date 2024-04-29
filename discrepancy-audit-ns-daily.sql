DECLARE @nmDays int;
DECLARE @searchStartTime datetime;
DECLARE @searchStopTime datetime;

SET @nmDays = 30;		/* << specify before execution */

SET @searchStartTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE())-@nmDays,0);
SET @searchStopTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0);

SELECT [Starting] = DATENAME(dw,@searchStartTime)+', '+LEFT(CONVERT(varchar,@searchStartTime,113),17)
	,[Ending] = DATENAME(dw,DATEADD(s,-1,@searchStopTime))+', '+LEFT(CONVERT(varchar,DATEADD(s,-1,@searchStopTime),113),17);

WITH Adjacent_Selector AS
(
SELECT *
	,Row_Selector = ROW_NUMBER() OVER (ORDER BY [Drug_Display_Name],[Event_Dttm])
FROM CRX_DATA.dbo.AHI_NARC_EVENT
WHERE [Station_Id] = 'nsta1'
)
SELECT
	CAST([Event_Dttm] AS datetime2(0)) AS [Event_Instant]
	,[Description]
	,[Drug_Display_Name]
	,[Event_Desc] =
		CASE
			WHEN [Class] = 'z' THEN 'Discrepancy'
			ELSE [Event_Class_Description]
		END
	,CAST([Trans_Qty] AS float) AS [Trans]
	,[Begin_Inventory_Level] AS [Begin]
	,[End_Inventory_Level] AS [End]
	,[Variance] =     --where a discrepancy exists, return difference between expected and input count
		CASE [Class]
			WHEN 'Z' THEN CAST([End_Inventory_Level]-[Begin_Inventory_Level] AS varchar)
			ELSE ''
		END
	,[Location_Id]
	,[Drug_Secure_Inventory] AS [Secure_Inv]
	,[User_Name]+' ('+CAST(User_Audit_Id AS varchar)+')' AS [User_Name_Id]
	,[Note]
	,[PO_Number]
	,[Event_Status]
	,[ZeroReturn] =
		CASE
			WHEN [User_Audit_Id] = '42901' AND [Trans_Qty] = 0 AND [Class] = 'r' THEN 'Y'
			ELSE ''
		END
	,[Process_Id]
	,[Process_Item_Id]
FROM Adjacent_Selector AS adjSel
WHERE Row_Selector IN
		(
		SELECT Row_Selector+i
		FROM Adjacent_Selector
		CROSS JOIN (SELECT -2 AS i UNION ALL SELECT -1 UNION ALL SELECT 0 UNION ALL SELECT 1) n
		WHERE [Class] = 'z'
			AND [Event_Dttm] BETWEEN @searchStartTime AND @searchStopTime
			AND [Event_Status] = 'u'
		)
ORDER BY Drug_Display_Name,Row_Selector;

/***** START OF QUERY 2 (PREVIOUS DAY ONLY) *****/

SET @nmDays = 1;
SET @searchStartTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE())-@nmDays,0);
SET @searchStopTime = DATEADD(dd,DATEDIFF(dd,0,GETDATE()),0);

SELECT [Starting] = DATENAME(dw,@searchStartTime)+', '+LEFT(CONVERT(varchar,@searchStartTime,113),17)
	,[Ending] = DATENAME(dw,DATEADD(s,-1,@searchStopTime))+', '+LEFT(CONVERT(varchar,DATEADD(s,-1,@searchStopTime),113),17);

WITH Adjacent_Selector AS
(
SELECT *
	,Row_Selector = ROW_NUMBER() OVER (ORDER BY [Drug_Display_Name],[Event_Dttm])
FROM CRX_DATA.dbo.AHI_NARC_EVENT
WHERE [Station_Id] = 'nsta1'
)
SELECT
	CAST([Event_Dttm] AS datetime2(0)) AS [Event_Instant]
	,[Description]
	,[Drug_Display_Name]
	,[Event_Desc] =
		CASE
			WHEN [Class] = 'z' THEN 'Discrepancy'
			ELSE [Event_Class_Description]
		END
	,CAST([Trans_Qty] AS float) AS [Trans]
	,[Begin_Inventory_Level] AS [Begin]
	,[End_Inventory_Level] AS [End]
	,[Variance] =     --where a discrepancy exists, return difference between expected and input count
		CASE [Class]
			WHEN 'Z' THEN CAST([End_Inventory_Level]-[Begin_Inventory_Level] AS varchar)
			ELSE ''
		END
	,[Location_Id]
	,[Drug_Secure_Inventory] AS [Secure_Inv]
	,[User_Name]+' ('+CAST(User_Audit_Id AS varchar)+')' AS [User_Name_Id]
	,[Note]
	,[PO_Number]
	,[Event_Status]
	,[ZeroReturn] =
		CASE
			WHEN [User_Audit_Id] = '42901' AND [Trans_Qty] = 0 AND [Class] = 'r' THEN 'Y'
			ELSE ''
		END
	,[Process_Id]
	,[Process_Item_Id]
FROM Adjacent_Selector AS adjSel
WHERE Row_Selector IN
		(
		SELECT Row_Selector+i
		FROM Adjacent_Selector
		CROSS JOIN (SELECT -2 AS i UNION ALL SELECT -1 UNION ALL SELECT 0 UNION ALL SELECT 1) n
		WHERE [Class] = 'z'
			AND [Event_Dttm] BETWEEN @searchStartTime AND @searchStopTime
		)
ORDER BY Drug_Display_Name, Row_Selector;
