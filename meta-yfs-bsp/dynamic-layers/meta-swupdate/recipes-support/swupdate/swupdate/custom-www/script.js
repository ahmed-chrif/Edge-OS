const fileInput = document.getElementById('file-input');
const fileLabel = document.getElementById('drop-zone');
const uploadBtn = document.getElementById('upload-btn');
const progressBar = document.getElementById('progress-bar');
const progressContainer = document.getElementById('progress-container');
const statusText = document.getElementById('status');

fileInput.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) {
        fileLabel.innerText = file.name;
        uploadBtn.disabled = false;
        statusText.innerText = 'Ready to update.';
    }
});

uploadBtn.addEventListener('click', () => {
    const file = fileInput.files[0];
    if (!file) return;

    // Detect extension type from filename
    const filename = file.name.toLowerCase();
    const isExtension = filename.includes('sysext') || filename.includes('confext');

    uploadBtn.disabled = true;
    fileInput.disabled = true;
    progressContainer.style.display = 'block';
    statusText.innerText = 'Uploading...';

    // 1. Construct multi-part form data
    const formData = new FormData();
    formData.append('file', file);

    const xhr = new XMLHttpRequest();
    xhr.timeout = 0; // Disable timeout during long flash operations

    xhr.open('POST', '/upload', true);

    xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
            const percent = (e.loaded / e.total) * 100;
            progressBar.style.width = percent + '%';
            if (percent < 100) {
                statusText.innerText = `Uploading: ${Math.round(percent)}%`;
            } else {
                statusText.innerText = isExtension
                    ? 'Upload complete. Applying system extension...'
                    : 'Upload complete. Flashing image to disk...';
            }
        }
    };

    xhr.onload = () => {
        if (xhr.status === 200) {
            // Tailor the success message based on image type
            if (isExtension) {
                statusText.innerText = 'Extension installed successfully!';
            } else {
                statusText.innerText = 'Update installed successfully! Rebooting...';
            }

            statusText.style.color = 'var(--success-color)';
            progressBar.style.backgroundColor = 'var(--success-color)';

            // Re-enable inputs for extension installs since no reboot occurs
            if (isExtension) {
                uploadBtn.disabled = false;
                fileInput.disabled = false;
            }
        } else {
            statusText.innerText = `Update failed: HTTP ${xhr.status}`;
            statusText.style.color = 'var(--error-color)';
            progressBar.style.backgroundColor = 'var(--error-color)';
            uploadBtn.disabled = false;
            fileInput.disabled = false;
        }
    };

    xhr.onerror = () => {
        statusText.innerText = 'Network error during upload.';
        statusText.style.color = 'var(--error-color)';
        progressBar.style.backgroundColor = 'var(--error-color)';
        uploadBtn.disabled = false;
        fileInput.disabled = false;
    };

    // 2. Send the FormData instance
    xhr.send(formData);
});