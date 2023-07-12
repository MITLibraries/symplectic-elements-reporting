--- Requested columns(https://support.symplectic.co.uk/a/tickets/439700):
--Elements Publication URL
--Repository Creation Date
--Publication Date
--Publication Type
--DSpace ID
--Recruitment Method
--OA Policy
--School or Faculty Name(here we can have multiple groups separated by a comma). A publication can be linked to multiple users from different groups.
--Data Source(here we can have multiple sources separated by a comma). A publication can have multiple records from different sources. 

--DECLARE @Start_Year INT = 1900;
--DECLARE @Group_IDs NVARCHAR(10) = '1';
--DECLARE @User_IDs NVARCHAR(10) = NULL;
-- DECLARE THE NEEDED VARIABLES:

-- carlj, 2023-05-02
DECLARE @Start_Year INT = 2022;
-- DECLARE @Group_IDs NVARCHAR(10) = '1';
DECLARE @Group_IDs NVARCHAR(10) = '307'
DECLARE @User_IDs NVARCHAR(10) = '4';


-- Get the ID of Recruitment Method label scheme
DECLARE @RecruitmentMethodSchemeID INT = (SELECT ID FROM [Label Scheme] WHERE [Name]='c-recruitment-method')
-- Get the ID of OA Faculty Policy
DECLARE @OAFacultyPolicyID INT = (SELECT ID FROM [OA Policy] WHERE [Name] = 'Faculty Policy')
-- Getthe DSpace source ID
DECLARE @DSpaceSourceID INT = (SELECT ID FROM [Publication Source] s WHERE s.[Name Identifier]='dspace')

-- Get the publication URL part
DECLARE @PublicationURLPart NVARCHAR(200) = (SELECT g.[Website Base URL]+'viewobject.html?cid=1&id=' FROM [Global Settings] g)

-- build a user list from the groups or users selected in Elements
;WITH selectedUsers AS (
	SELECT DISTINCT gu.[User ID] AS UserID
	FROM  [Group User Membership] gu 
	--Groups selecte din Elements
	JOIN (SELECT CAST(value AS INT) AS GroupID 
			FROM STRING_SPLIT(@Group_IDs, ',')
		) s ON gu.[Group ID] = s.GroupID
	UNION
	--users selected in Elements
	SELECT CAST(value AS INT) AS UserID
	FROM STRING_SPLIT(@User_IDs, ',')
)



SELECT    p.ID
	,@PublicationURLPart + CAST(p.ID AS NVARCHAR(10)) "PublicationURL"
	,pRecord.[record-created-at-source-date] "Repository Creation Date"
	,p.[publication-date] "Publication Date"
	,p.[Type] "Publication Type"
	,pRecord.[Data Source Proprietary ID] "DSpace ID"
	,ISNULL(pLabel.[Label],'No Label') "Recruitment Method"
	,CASE WHEN pOAPolicy.[Publication ID] IS NOT NULL THEN 'Yes' ELSE 'No' END "In Faculty Policy?"
	,CASE WHEN pOAPolicy.[Publication ID] IS NOT NULL THEN p.ID END "Faculty Policy"
	,CASE WHEN pOAPolicy.[Publication ID] IS  NULL THEN p.ID END "Not in Faculty Policy"
	--get the list of Primary groups for all linked users 
	,STUFF((SELECT DISTINCT '; ' +  u.[Primary Group Descriptor] FROM [Publication User Relationship] t 
		JOIN [User] ut ON t.[User ID] = ut.[ID]
		WHERE t.[Publication ID] = p.[ID]
		FOR XML PATH ('')),1,2,'')  "Primary Groups"
	--get the list of Sources
	,STUFF((SELECT '; ' + t.[Data Source] FROM [Publication Record] t 
		WHERE t.[Publication ID] = p.[ID]
		FOR XML PATH ('')),1,2,'')  "Data Sources"
FROM selectedUsers su
JOIN [User] u ON su.[UserID] = u.[ID]
JOIN [Publication User Relationship] r
	ON su.[UserID] = r.[User ID]
JOIN [Publication] p
	ON r.[Publication ID] = p.[ID]
JOIN [Publication Record] pRecord
	ON p.[ID] = pRecord.[Publication ID]
LEFT JOIN [Publication Label] pLabel
	ON p.[ID] = pLabel.[Publication ID] AND pLabel.[Scheme ID] = @RecruitmentMethodSchemeID
-- Join with OA Policy to check if the publication is part of Faculty Policy
LEFT JOIN [Publication OA Policy] pOAPolicy
	ON p.[ID] = pOAPolicy.[Publication ID] AND pOAPolicy.[OA Policy ID] = @OAFacultyPolicyID
-- Use the below line to filter by DSpace creation year. The value is set in a SSRS parameter
WHERE YEAR(pRecord.[record-created-at-source-date]) > @Start_Year
-- Consider only publications that are live in DSpace
	AND  pRecord.[Publication Source ID] = @DSpaceSourceID
	AND pRecord.[repository-status] = 'Public' 