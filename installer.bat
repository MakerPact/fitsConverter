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
python -c "import astropy" >nul 2>&1
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
(
echo import sys, os
echo import numpy as np
echo from astropy.io import fits
echo from PIL import Image
echo.
echo def main():
echo     if len(sys.argv) < 2:
echo         return
echo     filepath = sys.argv[1]
echo     print(f"Processing: {os.path.basename(filepath)}")
echo.
echo     try:
echo         hdul = fits.open(filepath)
echo         image_data = None
echo         for hdu in hdul:
echo             if hdu.data is not None and isinstance(hdu.data, np.ndarray) and hdu.data.ndim >= 2:
echo                 image_data = hdu.data.astype(np.float32)
echo                 break
echo         hdul.close()
echo.
echo         if image_data is None:
echo             print("Error: No 2D image data found in this FITS file.")
echo             return
echo.
echo         # Handle higher dimensional data if needed
echo         while image_data.ndim > 2:
echo             image_data = image_data[0]
echo.
echo         # Clean NaNs/Infs
echo         image_data = np.nan_to_num(image_data)
echo.
echo         # Apply percentile contrast stretch (similar to ds9 z-scale)
echo         vmin, vmax = np.percentile(image_data, (1.0, 99.0))
echo         if vmax > vmin:
echo             scaled = np.clip(image_data, vmin, vmax)
echo             scaled = (scaled - vmin) / (vmax - vmin) * 255.0
echo         else:
echo             scaled = np.zeros_like(image_data)
echo.
echo         scaled = scaled.astype(np.uint8)
echo.
echo         # Flip vertically to fix FITS bottom-left origin coordinate system
echo         scaled = np.flipud(scaled)
echo.
echo         # Save as PNG next to the original file
echo         out_path = os.path.splitext(filepath)[0] + ".png"
echo         Image.fromarray(scaled).save(out_path)
echo         print(f"Successfully converted! Saved to: {out_path}")
echo.
echo         # Try to open with GIMP if available
echo         try:
echo             os.startfile(out_path, "open")
echo         except Exception:
echo             pass
echo.
echo     except Exception as e:
echo         print(f"Error processing FITS file: {e}")
echo.
echo if __name__ == "__main__":
echo     main()
) > "%PY_SCRIPT%"

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
