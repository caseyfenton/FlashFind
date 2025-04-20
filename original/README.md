# Mdfind_override

A macOS optimization utility that automatically converts slow `find` commands to fast `mdfind` commands using the Spotlight index.

## Why Use This?

On macOS, the standard Unix `find` command can be extremely slow, especially on large directories or volumes with many files. This is because `find` must traverse the entire directory structure physically.

The macOS-native `mdfind` command leverages the Spotlight index, making searches drastically faster (often 10-100x) while using fewer system resources and less battery power.

## Features

- **Automatic Conversion**: All `find` commands are automatically converted to optimized `mdfind` commands
- **Zero Modification**: Existing scripts continue to work without any changes
- **System-Wide**: Works for all users and all shells
- **Smart Conversion**: Intelligently maps find's syntax to mdfind queries
- **Battery Efficient**: Uses indexed search instead of traversing the filesystem

## Installation

```bash
# One-command installation
./install.sh

# Or manual installation
sudo mkdir -p /usr/local/etc/shell_extensions
sudo cp src/find_to_mdfind.sh /usr/local/etc/shell_extensions/
sudo mkdir -p /etc/zshenv.d
echo 'source /usr/local/etc/shell_extensions/find_to_mdfind.sh' | sudo tee -a /etc/bashrc
echo 'alias_find_to_mdfind' | sudo tee -a /etc/bashrc
```

## Usage

After installation, all `find` commands in your terminal will automatically use `mdfind` instead:

```bash
# This command:
find ~/Documents -name "*.pdf" -mtime -7

# Is converted to:
mdfind -onlyin ~/Documents "kMDItemFSName = '*.pdf' && kMDItemFSContentChangeDate > $time.today(-7)"
```

## Supported Find Options

- `-name`: Converted to kMDItemFSName queries
- `-type`: Supports f (file) and d (directory)
- `-mtime`: Converted to date-based queries
- `-maxdepth`: Respected during conversion

## License

MIT

## Author

Original author: Casey
GitHub: https://github.com/yourusername/Mdfind_override
