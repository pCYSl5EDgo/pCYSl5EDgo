import { promise as lz4promise } from './messagepack_lz4.js';

const testFunction = async (blob) => {
    const lz4 = await lz4promise;
    const originalBytes = new Uint8Array(await blob.arrayBuffer());
    const compressedBytes = lz4.compress(originalBytes);
    if (compressedBytes instanceof Error)
        return compressedBytes;
    console.log("compression currenlty passes");
    const copyOriginal = compressedBytes.slice();
    const restore = lz4.decompress(copyOriginal, originalBytes.byteLength);
    if (restore instanceof Error) { return restore; }
    const copyRestore = restore.slice();
    for (let index = 0; index < restore.length; index++) {
        const element = restore[index];
        const rightElement = originalBytes[index];
        if (element != rightElement)
            return new Error("different element at " + index.toString());
    }
    console.log("decompression success!!!!");
    return [copyOriginal, copyRestore];
};
window.addEventListener("DOMContentLoaded", async () => {
    console.log("loaded");
    const byteLengthInput = document.getElementById("file-bytelength");
    if (!byteLengthInput) {
        throw new Error("file-bytelength not found!");
    }
    const fileInput = document.getElementById("file-input");
    if (!fileInput) {
        throw new Error("file-input not found!");
    }
    const compressedFileList = document.getElementById("compressed-file-list");
    if (!compressedFileList) {
        throw new Error("compressed file list not found!");
    }
    const decompressedFileList = document.getElementById("decompressed-file-list");
    if (!decompressedFileList) {
        throw new Error("compressed file list not found!");
    }
    const itemTemplate = document.getElementById("template-compress");
    if (!itemTemplate) {
        throw new Error("template not found!");
    }
    const compressButton = document.getElementById("file-compress");
    if (!compressButton) {
        throw new Error("compress button not found!");
    }
    const compressClick = async () => {
        console.log("clocked");
        const files = fileInput.files;
        if (!files || files.length === 0) {
            console.log("empty files");
            return;
        }
        const lz4 = await lz4promise;
        console.log(lz4.offset + " is offset");
        const getBufferJob = [];
        for (let index = 0; index < files.length; index++) {
            const file = files.item(index);
            if (!file || file.size === 0) {
                console.log("file empty continue;");
                continue;
            }
            console.log("file size : " + file.size.toString());
            const job = (async () => {
                const buffer = await file.arrayBuffer();
                console.log("buffer size" + buffer.byteLength.toString());
                const binary = await testFunction(file);
                if (binary instanceof Error) { throw binary; }
                return {
                    name: file.name,
                    compressed: new Blob([binary[0]]),
                    restored: new Blob([binary[1]]),
                };
            })();
            getBufferJob.push(job);
        }
        console.log("jobs count:" + getBufferJob.length.toString());
        const buffers = await Promise.allSettled(getBufferJob);
        for (const buffer of buffers) {
            if (buffer.status === "fulfilled") {
                const value = buffer.value;
                if (!value) { continue; }
                {
                    const copy = itemTemplate.content.cloneNode(true);
                    console.log("copy clone!");
                    const liElement = copy.querySelector("li");
                    if (!liElement) {
                        throw new Error("not li");
                    }
                    const anchorElement = liElement.querySelector("a");
                    if (!anchorElement) {
                        throw new Error("not anchor");
                    }
                    anchorElement.textContent = value.name + ".lz4";
                    anchorElement.href = URL.createObjectURL(value.compressed);
                    compressedFileList.appendChild(copy);
                }

                {
                    const copy = itemTemplate.content.cloneNode(true);
                    console.log("copy clone!");
                    const liElement = copy.querySelector("li");
                    if (!liElement) {
                        throw new Error("not li");
                    }
                    const anchorElement = liElement.querySelector("a");
                    if (!anchorElement) {
                        throw new Error("not anchor");
                    }
                    anchorElement.textContent = value.name;
                    anchorElement.href = URL.createObjectURL(value.restored);
                    compressedFileList.appendChild(copy);
                }
            }
            else if (buffer.status === "rejected") {
                console.log("rejected" + buffer.reason);
            }
        }
    };
    compressButton.addEventListener("click", compressClick);
});
