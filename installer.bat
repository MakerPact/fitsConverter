@echo off
setlocal

:: Check if a file was dragged and dropped onto the script
if "%~1"=="" (
    echo.
    echo ============================================
    echo   FITS to PNG Converter for Astronomy
    echo ============================================
    echo.
    echo [ERROR] No FITS file provided.
    echo.
    echo Please drag and drop a .fit or .fits file onto this batch script!
    echo.
    pause
    exit /b
)

:: Validate that the dropped file is actually a FITS file
if not "%~x1"==".fit" if not "%~x1"==".fits" (
    echo.
    echo ============================================
    echo   FITS to PNG Converter for Astronomy
    echo ============================================
    echo.
    echo [ERROR] Unsupported file type: %~nx1
    echo.
    echo Only .fit and .fits files are supported.
    echo.
    pause
    exit /b
)

echo.
echo ============================================
echo   FITS to PNG Converter for Astronomy
echo ============================================
echo.
echo [1/5] Checking Python 3 installation...
echo.

:: Detect Python 3
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Python 3 is not installed or not in your system PATH.
    echo.
    echo This tool requires Python 3.8+ and pip.
    echo.
    echo Please install Python 3 from:
    echo   https://www.python.org/downloads/
    echo.
    echo During installation, CHECK the box that says:
    echo   "Add Python to PATH"
    echo.
    echo After installation, close this window and
    echo   restart your terminal, then try again.
    echo.
    pause
    exit /b
)

:: Check pip is available
python -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] pip is not installed or not in your system PATH.
    echo.
    echo Please install Python 3 from python.org.
    echo Make sure to check "Add Python to PATH" during installation.
    echo.
    pause
    exit /b
)

echo.
echo [2/5] Checking and installing Python dependencies...
echo.

:: Check each dependency individually
set "MISSING_DEPS="
python -c "import astropy" >nul 2>&1
if errorlevel 1 set "MISSING_DEPS=%MISSING_DEPS% astropy"
python -c "import numpy" >nul 2>&1
if errorlevel 1 set "MISSING_DEPS=%MISSING_DEPS% numpy"
python -c "import PIL" >nul 2>&1
if errorlevel 1 set "MISSING_DEPS=%MISSING_DEPS% pillow"

if "%MISSING_DEPS%"=="" (
    echo All required libraries are already installed.
) else (
    echo Installing missing libraries: %MISSING_DEPS%
    echo.
    echo This may take several minutes on the first run...
    echo.
    echo Upgrading pip...
    python -m pip install --upgrade pip
    echo.
    echo Installing astronomy and image processing libraries...
    python -m pip install astropy numpy pillow
    echo.
    echo Dependencies installed successfully.
)

echo.
echo [3/5] Preparing conversion engine...
echo.

:: Write a temporary Python script to handle the heavy lifting
set "PY_SCRIPT=%temp%\fits_converter_temp.py"
if exist "%PY_SCRIPT%" del "%PY_SCRIPT%"
>>"%PY_SCRIPT%" echo import sys, os
>>"%PY_SCRIPT%" echo import numpy as np
>>"%PY_SCRIPT%" echo from astropy.io import fits
>>"%PY_SCRIPT%" echo from PIL import Image
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo def main():
>>"%PY_SCRIPT%" echo     if len(sys.argv) ^< 2:
>>"%PY_SCRIPT%" echo         return
>>"%PY_SCRIPT%" echo     filepath = sys.argv[1]
>>"%PY_SCRIPT%" echo     print(f"Processing: {os.path.basename(filepath)}")
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo     try:
>>"%PY_SCRIPT%" echo         hdul = fits.open(filepath)
>>"%PY_SCRIPT%" echo         image_data = None
>>"%PY_SCRIPT%" echo         for hdu in hdul:
>>"%PY_SCRIPT%" echo             if hdu.data is not None and isinstance(hdu.data, np.ndarray) and hdu.data.ndim ^>= 2:
>>"%PY_SCRIPT%" echo                 image_data = hdu.data.astype(np.float32)
>>"%PY_SCRIPT%" echo                 break
>>"%PY_SCRIPT%" echo         hdul.close()
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         if image_data is None:
>>"%PY_SCRIPT%" echo             print("Error: No 2D image data found in this FITS file.")
>>"%PY_SCRIPT%" echo             return
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         # Handle higher dimensional data if needed
>>"%PY_SCRIPT%" echo         while image_data.ndim ^> 2:
>>"%PY_SCRIPT%" echo             image_data = image_data[0]
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         # Clean NaNs/Infs
>>"%PY_SCRIPT%" echo         image_data = np.nan_to_num(image_data)
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         # Apply percentile contrast stretch (similar to ds9 z-scale)
>>"%PY_SCRIPT%" echo         vmin, vmax = np.percentile(image_data, (1.0, 99.0))
>>"%PY_SCRIPT%" echo         if vmax ^> vmin:
>>"%PY_SCRIPT%" echo             scaled = np.clip(image_data, vmin, vmax)
>>"%PY_SCRIPT%" echo             scaled = (scaled - vmin) / (vmax - vmin) * 255.0
>>"%PY_SCRIPT%" echo         else:
>>"%PY_SCRIPT%" echo             scaled = np.zeros_like(image_data)
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         scaled = scaled.astype(np.uint8)
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         # Flip vertically to fix FITS bottom-left origin coordinate system
>>"%PY_SCRIPT%" echo         scaled = np.flipud(scaled)
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         # Save as PNG next to the original file
>>"%PY_SCRIPT%" echo         out_path = os.path.splitext(filepath)[0] + ".png"
>>"%PY_SCRIPT%" echo         Image.fromarray(scaled).save(out_path)
>>"%PY_SCRIPT%" echo         print(f"Successfully converted! Saved to: {out_path}")
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo         # Try to open with GIMP if available
>>"%PY_SCRIPT%" echo         try:
>>"%PY_SCRIPT%" echo             os.startfile(out_path, "open")
>>"%PY_SCRIPT%" echo         except Exception:
>>"%PY_SCRIPT%" echo             pass
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo     except Exception as e:
>>"%PY_SCRIPT%" echo         print(f"Error processing FITS file: {e}")
>>"%PY_SCRIPT%" echo.
>>"%PY_SCRIPT%" echo if __name__ == "__main__":
>>"%PY_SCRIPT%" echo     main()

if not exist "%PY_SCRIPT%" (
    echo [ERROR] Failed to create conversion script.
    echo Please try running this script again.
    pause
    exit /b
)

echo.
echo [4/5] Converting FITS file...
echo.

python "%PY_SCRIPT%" "%~1"

:: Clean up temporary file
if exist "%PY_SCRIPT%" del "%PY_SCRIPT%"

echo.
echo ============================================
echo   Conversion Complete!
echo ============================================
echo.
echo The image has been saved as a PNG file next to
echo your original FITS file.
echo.
echo If GIMP is installed, it should have opened
echo automatically. Otherwise, you can open the PNG
echo file manually.
echo.
echo ============================================
pause
