CREATE FUNCTION [ME_Data].[fn_StripNonSupportedPqtColChars] (@TXT [VARCHAR](MAX),@ReplaceChar [VARCHAR](10)) RETURNS VARCHAR(MAX)
AS
BEGIN
	DECLARE @Return VARCHAR(MAX)
    SET @Return =	(REPLACE(
						REPLACE(
							REPLACE(
									REPLACE(
											REPLACE(
													REPLACE(
															REPLACE(
																	REPLACE(
																			REPLACE(@TXT,',',@ReplaceChar)
																	,';',@ReplaceChar)
															,'{',@ReplaceChar)
													,'}',@ReplaceChar)
											,'(',@ReplaceChar)
									,')',@ReplaceChar)
							,'=',@ReplaceChar)
						,'\',@ReplaceChar)
					,' ',@ReplaceChar))
															   	/*[,;{}()\n\t=]*/

    RETURN @Return
END