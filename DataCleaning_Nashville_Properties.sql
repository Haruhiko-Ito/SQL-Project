Select *
From Project.dbo.Sheet1;

-- Standardize 'Sale Date'

-- Select SaleDate, CONVERT(date, SaleDate)
-- From Project.dbo.Sheet1;
-- Update Project..Sheet1
-- Set SaleDate = CONVERT(date, SaleDate);

Alter Table Sheet1
Add SaleDateConverted date;
Update Sheet1
SET SaleDateConverted = CONVERT(date, SaleDate);



------------------------------------------------------------------------------------------------------------------
-- Populate Property Address (where Property Address is null)

-- We can see that some 'PropertyAddress' is null
Select *
From Project.dbo.Sheet1
Where PropertyAddress is null ;

-- Check that 'ParcelID' matches with 'PropertyAddress'
Select *
From Project.dbo.Sheet1
Order By ParcelID;
-- Therefore, we can populate 'PropertyAddress' based on ParcelID

-- Need to join table to itself
Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress
From Project.dbo.Sheet1 as a
Join Project.dbo.Sheet1 as b
	ON a.ParcelID = b.ParcelID
	And a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null
;

-- Use 'ISNULL' stating: if a.PropertyAddress is null, use b.PropertyAddress
Select a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress, ISNULL(a.PropertyAddress, b.PropertyAddress)
From Project.dbo.Sheet1 as a
Join Project.dbo.Sheet1 as b
	ON a.ParcelID = b.ParcelID
	And a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null
;

-- Now, transfer the ISNULL to PropertyAddress
UPDATE a
SET PropertyAddress = ISNULL(a.PropertyAddress, b.PropertyAddress)
From Project.dbo.Sheet1 as a
Join Project.dbo.Sheet1 as b
	ON a.ParcelID = b.ParcelID
	And a.[UniqueID ] <> b.[UniqueID ]
Where a.PropertyAddress is null
;



-----------------------------------------------------------------------------------------------------------
-- Breaking out Address into Individual Columns (Address, City, State)

--Note that there is only one delimiter ',' --> separates Address & City
Select PropertyAddress
From Project.dbo.Sheet1;

Select 
SUBSTRING (PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1) as Address
, SUBSTRING (PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) as City
From Project.dbo.Sheet1
;

-- In the 1st substring: We're looking at PropertyAddress
-- The '1' commands that we want to look from the very first value of PropertyAddress (which is the very first letter)
-- Then, the CHARINDEX provides us with a location up to & including ',' --> all outputs will have comma at the end
-- So we do '-1' to reduce all the comma
-- Summary: Select 'PropertyAddress' --> start from the first letter --> up to & including comma --> get rid of the last value (which is comma)
-- Then, name this selection as Address

-- 2nd substring: Select 'PropertyAddress' --> Start from ',' and go to the next value (so that we don't include comma in result)
-- --> end with the last value of PropertyAddress --> name this as State


-- Now that we figured out how to separate Property Address column into Address & city
-- Need to add 2 new columns
ALTER Table Sheet1
Add PropertySplitAddress nvarchar(255) ;
Update Sheet1
Set PropertySplitAddress = SUBSTRING (PropertyAddress, 1, CHARINDEX(',', PropertyAddress) -1);

Alter Table Sheet1
Add PropertySplitCity nvarchar(255) ;
Update Sheet1
Set PropertySplitCity = SUBSTRING (PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress));

Select *
From Sheet1 ;


-- Now let's split Owner Address
-- Using ParseName

-- ParseName only looks for '.' --> lets change ',' into '.'
-- Then look at where '1' is referring to --> ParseName looks things backward
-- '3' = address ; '2' = city ; '3' = state
Select
PARSENAME(Replace(OwnerAddress, ',', '.'), 3),
PARSENAME(Replace(OwnerAddress, ',', '.'), 2),
PARSENAME(Replace(OwnerAddress, ',', '.'), 1)
From Project.dbo.Sheet1 ;

Alter Table Sheet1
Add OwnerSplitAddress nvarchar(255);
Update Sheet1
Set OwnerSplitAddress = PARSENAME(Replace(OwnerAddress, ',', '.'), 3)
;

Alter Table Sheet1
Add OwnerSplitCity nvarchar(255);
Update Sheet1
Set OwnerSplitCity = PARSENAME(Replace(OwnerAddress, ',', '.'), 2);

Alter Table Sheet1
Add OwnerSplitState nvarchar(255);
Update Sheet1
Set OwnerSplitState = PARSENAME(Replace(OwnerAddress, ',', '.'), 1);

Select *
From Project.dbo.Sheet1 ;



----------------------------------------------------------------------------------------------
-- Change Y & N --> Yes & No for "Sold as Vacant"

-- Current state of the table:
Select Distinct(SoldAsVacant), COUNT(SoldAsVacant)
From Project.dbo.Sheet1
Group By SoldAsVacant
Order By 2
;

-- Use CASE statement
Select SoldAsVacant,
	CASE WHEN SoldAsVacant = 'Y' then 'Yes'
		WHEN SoldAsVacant = 'N' then 'No'
		ELSE SoldAsVacant
		END
From Project.dbo.Sheet1
;

-- Transfer this result into our table
Update Sheet1
Set SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' then 'Yes'
		WHEN SoldAsVacant = 'N' then 'No'
		ELSE SoldAsVacant
		END
;

------------------------------------------------------------------------------------------------
-- Remove Duplicates

-- Created new column called 'row_n' that counts the number of rows that are duplicates (based on the partition by statement)
Select *, 
ROW_NUMBER() Over (
		Partition By ParcelID,
					 PropertyAddress,
					 SalePrice,
					 SaleDate,
					 LegalReference
		Order by UniqueID)
		row_num
From Project.dbo.Sheet1
Order by ParcelID
;


-- Now create a CTE so that we can make more specific commands
With RowNumCTE AS(
Select *, 
ROW_NUMBER() Over (
		Partition By ParcelID,
					 PropertyAddress,
					 SalePrice,
					 SaleDate,
					 LegalReference
		Order by UniqueID)
		row_num
From Project.dbo.Sheet1
--Order by ParcelID
)
Select *
From RowNumCTE
Where row_num > 1
Order by PropertyAddress
;


-- Now we can see all the duplicates
-- Let's drop all duplicates from the table
-- Note, since CTEs can only be used for a single query, we need C+V from above
With RowNumCTE AS(
Select *, 
ROW_NUMBER() Over (
		Partition By ParcelID,
					 PropertyAddress,
					 SalePrice,
					 SaleDate,
					 LegalReference
		Order by UniqueID)
		row_num
From Project.dbo.Sheet1
--Order by ParcelID
)
Delete
From RowNumCTE
Where row_num > 1
-- Order by PropertyAddress
;


-------------------------------------------------------------------------------------------------
-- Delete unused columns

-- Since we split the PropertyAddress & OwnerAddress, let's drop those two
Alter Table Project.dbo.Sheet1
Drop Column OwnerAddress, TaxDistrict, PropertyAddress;

Alter Table Project.dbo.Sheet1
Drop Column SaleDate;

Select *
From Project.dbo.Sheet1;