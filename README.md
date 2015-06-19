IMGTreeTableView
===============

## Features

 - Allows arbitrarily deeply nested comments (or any other data element)
 - Automatically collapses comments upon reaching a certain depth threshold
 - 'Actionable' cell, used as a comment reply cell in Imgur, only exists in one location
 - 'Selectable' cell, used as a comment actions panel in Imgur, only exists in one location
 - Animated transitions during collapse or comment expanson, never reloading
 
## Configuration

- Use a constructor conforming to IMGTreeConstructorDelegate to construct the node tree to be represented
- Conform to the IMGTreeTableControllerDelegate protocol in a view controller to provide custom table view cells for each node
- Pass-through pattern on the IMGTreeTableController to allow custom UITableView's to be used for maximum flexibility
