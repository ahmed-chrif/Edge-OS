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

    uploadBtn.disabled = true;
    fileInput.disabled = true;
    progressContainer.style.display = 'block';
    statusText.innerText = 'Uploading...';

    const xhr = new XMLHttpRequest();

    // SWUpdate's built-in webserver listens for POSTs on /upload
    xhr.open('POST', '/upload', true);

    xhr.upload.onprogress = (e) => {
        if (e.lengthComputable) {
            const percent = (e.loaded / e.total) * 100;
            progressBar.style.width = percent + '%';
            statusText.innerText = `Uploading: ${Math.round(percent)}%`;
        }
    };

    xhr.onload = () => {
        if (xhr.status === 200) {
            statusText.innerText = 'Update installed successfully! Rebooting...';
            statusText.style.color = 'var(--success-color)';
            progressBar.style.backgroundColor = 'var(--success-color)';
        } else {
            statusText.innerText = `Update failed: ${xhr.statusText}`;
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
    };

    xhr.send(file);
});